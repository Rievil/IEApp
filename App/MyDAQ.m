classdef MyDAQ < handle
    properties
        Devlist;
        TriggerLevelEditField=0.05;
        TriggerDelay=-0.05;
        CaptureDuration=0.5;
        ViewTimeWindow=1;
        AcData;
        TriggerType='Rising';
        DAQ;
        Han;
        Parent;
        UIPanel;
    end

    properties (Hidden)
        TimestampsFIFOBuffer;
        DataFIFOBuffer;
        CaptureStartMoment;
        Data;
        Timestamps;
        TrigActive;
        TrigMoment;
        BufferSize;
        Ax;
        BufferTimeSpan;
        CallbackTimeSpan;
        CurrentState;
        MeasureState;
        CaptureData;
        CaptureTimestamps;
    end

    events
        SignalReady;
    end
    
    methods
        function obj=MyDAQ(parent)
            obj.Parent=parent;
            obj.Devlist = daqlist;
            idx=find(contains(obj.Devlist.Model,'carlett') & contains(obj.Devlist.Model,'ikrofon'));
            deviceIndex = idx;
            deviceID = obj.Devlist.DeviceID(deviceIndex);
            vendor = obj.Devlist.DeviceInfo(deviceIndex).Vendor.ID;
            measurementType=obj.Devlist.DeviceInfo(deviceIndex).Subsystems.DefaultMeasurementType;
            
            d = daq(vendor);
            addinput(d, deviceID, 1, measurementType);
           
            % Configure DAQ ScansAvailableFcn callback function
            d.ScansAvailableFcn = @obj.M_scans;
            d.Rate=100000;
            obj.DAQ=d;
            obj.CallbackTimeSpan = double(obj.DAQ.ScansAvailableFcnCount)/obj.DAQ.Rate;
        end

        function DrawGUI(obj,panel)
            obj.UIPanel=panel;
            g=uigridlayout(obj.UIPanel);
            g.RowHeight = {25,25,25,25,'1x'};
            g.ColumnWidth = {'1x',50};

            lab=uilabel(g,'Text','Duration (s):');
            lab.Layout.Row=1;
            lab.Layout.Column=1;

            uid1=uieditfield(g,"numeric","Limits",[0.1,1]);
            uid1.Value=obj.CaptureDuration;
            uid1.Layout.Row=1;
            uid1.Layout.Column=2;

            lab=uilabel(g,'Text','Trigger (V):');
            lab.Layout.Row=2;
            lab.Layout.Column=1;

            uid2=uieditfield(g,"numeric","Limits",[0,1]);
            uid2.Value=obj.TriggerLevelEditField;
            uid2.Layout.Row=2;
            uid2.Layout.Column=2;

            lab=uilabel(g,'Text','Sampling rate (Hz):');
            lab.Layout.Row=3;
            lab.Layout.Column=1;

            uid3=uieditfield(g,"numeric","Limits",[0,192000]);
            uid3.Value=obj.DAQ.Rate;
            uid3.Layout.Row=3;
            uid3.Layout.Column=2;

            lab=uilabel(g,'Text','Max freq limit (Hz):');
            lab.Layout.Row=4;
            lab.Layout.Column=1;

            uid4=uieditfield(g,"numeric","Limits",[0,obj.DAQ.Rate/2]);
            uid4.Value=6000;
            uid4.Layout.Row=4;
            uid4.Layout.Column=2;
        end

        

        function start(obj)
            obj.TimestampsFIFOBuffer=[];
            obj.DataFIFOBuffer=[];
            obj.calculateBufferSize(obj.CallbackTimeSpan, obj.ViewTimeWindow, obj.TriggerDelay, obj.CaptureDuration, obj.DAQ.Rate);
            obj.CurrentState = 'Acquisition.Buffering';
            % obj.DrawGUI;
            % start(obj.DAQ, "Duration", seconds(5));
            start(obj.DAQ, "continuous");
        end

        function M_scans(obj,src,evnt)
            [data,timestamps] = read(src, src.ScansAvailableFcnCount, 'OutputFormat','Matrix');
            % Store continuous acquisition data in FIFO data buffers
            obj.TimestampsFIFOBuffer = storeDataInFIFO(obj, obj.TimestampsFIFOBuffer, obj.BufferSize, timestamps);
            obj.DataFIFOBuffer = storeDataInFIFO(obj, obj.DataFIFOBuffer, obj.BufferSize, data(:,1));
            
            % Update live plot data
            samplesToPlot = min([round(obj.ViewTimeWindow * src.Rate), size(obj.DataFIFOBuffer,1)]);
            firstPoint = size(obj.DataFIFOBuffer, 1) - samplesToPlot + 1;
            if samplesToPlot > 1
                % xlim(obj.Ax, [obj.TimestampsFIFOBuffer(firstPoint), obj.TimestampsFIFOBuffer(end)])
            end
            
            % x=obj.TimestampsFIFOBuffer(firstPoint:end);
            % y=obj.DataFIFOBuffer(firstPoint:end);

            % set(obj.Han, 'XData', x,'YData', y);

            if isempty(obj.Timestamps)
                obj.Data = data(:,1);
                obj.Timestamps = timestamps;
            else
                obj.Data = [obj.Data(end,1); data(:,1)];
                obj.Timestamps = [obj.Timestamps(end); timestamps];
            end

            % App state control logic 
            switch obj.CurrentState
                case 'Acquisition.Buffering'
                   % Buffering pre-trigger data
                    if isEnoughDataBuffered(obj)
                        obj.CurrentState = 'Acquisition.ReadyForCapture';
                    end
                case 'Acquisition.ReadyForCapture'
                    % Ready for capture

                    obj.CurrentState = 'Capture.LookingForTrigger';

                case 'Capture.LookingForTrigger'
                    % Looking for trigger event in the latest data
                    detectTrigger(obj)
                    if obj.TrigActive
                        obj.CurrentState = 'Capture.CapturingData';
                    end
                case 'Capture.CapturingData'
                    % Capturing data
                    % Not enough acquired data to cover capture timespan during this ScansAvailable callback execution
                    if isEnoughDataCaptured(obj)
                        obj.CurrentState = 'Capture.CaptureComplete';
                    end
                case 'Capture.CaptureComplete'
                    % Acquired enough data to complete capture of specified duration
                    completeCapture(obj)
                    obj.CurrentState = 'Acquisition.ReadyForCapture';
                    if obj.MeasureState==true
                        obj.CurrentState = 'Capture.LookingForTrigger';
                    end
            end
        end

    end

    methods
        function calculateBufferSize(obj, callbackTimeSpan, liveViewTimeSpan, triggerDelay, captureDuration, rate)
            if triggerDelay < 0
                bufferTimeSpan = max([abs(triggerDelay), captureDuration, liveViewTimeSpan]);
            else
                bufferTimeSpan = max([captureDuration, liveViewTimeSpan]);
            end
            obj.BufferTimeSpan = bufferTimeSpan + 2*callbackTimeSpan;
            obj.BufferSize = ceil(rate * bufferTimeSpan) + 1;
        end

        function detectTrigger(obj)
            trigConfig.Channel = 1;
            trigConfig.Level = obj.TriggerLevelEditField;
            trigConfig.Condition = obj.TriggerType;
            [obj.TrigActive, obj.TrigMoment] = trigDetect(obj, obj.Timestamps, obj.Data, trigConfig);
            obj.CaptureStartMoment = obj.TrigMoment + obj.TriggerDelay;
        end

        function completeCapture(obj)
                %completeCapture Saves captured data to workspace variable and plots it
            
            % Find index of first sample in data buffer to be captured
            firstSampleIndex = find(obj.TimestampsFIFOBuffer >= obj.CaptureStartMoment, 1, 'first');
            
            % Find index of last sample in data buffer that complete the capture
            lastSampleIndex = firstSampleIndex + round(obj.CaptureDuration * obj.DAQ.Rate);
            % if isempty(firstSampleIndex) || isempty(lastSampleIndex) || lastSampleIndex > size(obj.TimestampsFIFOBuffer, 1)
            %     % Something went wrong
            %     % Abort capture
            %     obj.StatusText.Text = 'Capture error';
            %     obj.CaptureButton.Value = 0;
            %     uialert(obj.AnalogTriggerAppExampleUIFigure, 'Could not complete capture.', 'Capture error');
            %     return
            % end
            
            % Extract capture data and shift timestamps so that 0 corresponds to the trigger moment
            obj.CaptureData = obj.DataFIFOBuffer(firstSampleIndex:lastSampleIndex);
            obj.CaptureTimestamps = obj.TimestampsFIFOBuffer(firstSampleIndex:lastSampleIndex, :) - obj.TrigMoment;

            timesam=datetime('now');
            freq=obj.DAQ.Rate;
            period=1/freq;
            samples=numel(obj.CaptureTimestamps);
            duration=samples*period;
            
            sig=struct;
            obj.AcData=table(timesam,{obj.CaptureData},obj.CaptureTimestamps(1),obj.CaptureTimestamps(end),...
                freq,duration,samples,'VariableNames',["Time","Signal","StartTime","EndTime","SamplingFrequency","Duration","Samples",]);

            notify(obj,'SignalReady');
        end

        function [trigDetected, trigMoment] = trigDetect(~, timestamps, data, trigConfig)  
            switch trigConfig.Condition
                case 'Rising'
                    % Logical array condition for signal trigger level
                    trigConditionMet = data(:, trigConfig.Channel) > trigConfig.Level;
                case 'Falling'
                    % Logical array condition for signal trigger level
                    trigConditionMet = data(:, trigConfig.Channel) < trigConfig.Level;
            end
            
            trigDetected = any(trigConditionMet) & ~all(trigConditionMet);
            trigMoment = [];
            if trigDetected
                % Find time moment when trigger condition has been met
                trigMomentIndex = 1 + find(diff(trigConditionMet)==1, 1, 'first');
                trigMoment = timestamps(trigMomentIndex);
            end
        end

        
        function results = isEnoughDataCaptured(obj)
        %isEnoughDataCaptured Check whether captured-data duration exceeds specified capture duration
            results = (obj.TimestampsFIFOBuffer(end,1)-obj.CaptureStartMoment) > obj.CaptureDuration;
        end
        
        function results = doesTriggerDelayChangeRequireBuffering(obj)
        
            value = obj.TriggerLevelEditField;
            if value < 0 && size(obj.TimestampsFIFOBuffer,1) < ceil(abs(value)*obj.DAQ.Rate)
                results = true;
            else
                results = false;
            end            
        end

        function results = isEnoughDataBuffered(obj)
        %isEnoughDataBuffered Checks whether buffering pre-trigger data is complete    
       
            % If specified trigger delay is less than 0, need to check
            % whether enough pre-trigger data is buffered so that a
            % triggered capture can be requested
            results = (obj.TriggerDelay >= 0) || ...
                (size(obj.TimestampsFIFOBuffer,1) > ceil(abs(obj.TriggerDelay)*obj.DAQ.Rate));
        end


        function data = storeDataInFIFO(~, data, buffersize, datablock)
            if size(data,1) > buffersize
                data = data(end-buffersize+1:end,:);
            end
            
            if size(datablock,1) < buffersize
                % Data block size (number of rows) is smaller than the buffer size
                if size(data,1) == buffersize
                    % Current data size is already equal to buffer size.
                    % Discard older data and append new data block,
                    % and keep data size equal to buffer size.
                    shiftPosition = size(datablock,1);
                    data = circshift(data,-shiftPosition);
                    data(end-shiftPosition+1:end,:) = datablock;
                elseif (size(data,1) < buffersize) && (size(data,1)+size(datablock,1) > buffersize)
                    % Current data size is less than buffer size and appending the new
                    % data block results in a size greater than the buffer size.
                    data = [data; datablock];
                    shiftPosition = size(data,1) - buffersize;
                    data = circshift(data,-shiftPosition);
                    data(buffersize+1:end, :) = [];
                else
                    % Current data size is less than buffer size and appending the new
                    % data block results in a size smaller than or equal to the buffer size.
                    % (if (size(data,1) < buffersize) && (size(data,1)+size(datablock,1) <= buffersize))
                    data = [data; datablock];
                end
            else
                % Data block size (number of rows) is larger than or equal to buffer size
                data = datablock(end-buffersize+1:end,:);
            end
        end


    end
end