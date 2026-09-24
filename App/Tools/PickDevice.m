classdef PickDevice < handle
    properties
        Parent;
        UIFig;
        UITable;
        UIButtonPick;
        UIButtonCancle;
        Devlist;
        Data;
        RowDevice=0;
        LastError='';
    end

    methods
        function obj=PickDevice(parent)
            obj.Parent=parent;
            RefreshDevlist(obj);
        end

        function RefreshDevlist(obj)
            try
                obj.Devlist = daqlist;
                obj.LastError='';
            catch err
                obj.Devlist = table();
                obj.LastError=err.message;
                warning('IEApp:PickDevice:daqlist','Device enumeration failed: %s',err.message);
            end
        end

        function DrawGUI(obj)
            obj.UIFig=uifigure('Name','Select measurement device');
            g=uigridlayout(obj.UIFig);
            g.RowHeight = {25,'1x',50};
            g.ColumnWidth = {200,'1x',200};

            obj.UITable=uitable(g,'CellSelectionCallback',@obj.MPickID);
            obj.UITable.Layout.Row=2;
            obj.UITable.Layout.Column=[1 3];

            but1=uibutton(g,'Text','Select device','ButtonPushedFcn',@obj.SetVendor);
            but1.Layout.Row=3;
            but1.Layout.Column=1;
            obj.UIButtonPick=but1;

            but2=uibutton(g,'Text','Refresh devices','ButtonPushedFcn',@obj.MRefresh);
            but2.Layout.Row=3;
            but2.Layout.Column=3;

            FillTable(obj);
        end

        function FillTable(obj)
            obj.RowDevice=0;
            if isempty(obj.Devlist)
                obj.Data=table();
                obj.UITable.Data=obj.Data;
                if isempty(obj.LastError)
                    msg=['No measurement device was found. Connect the audio '...
                        'interface or microphone and press "Refresh devices". '...
                        'If a device is connected, make sure the "Data Acquisition '...
                        'Toolbox Support Package for Windows Sound Cards" is installed.'];
                else
                    msg=sprintf('Device enumeration failed:\n%s',obj.LastError);
                end
                uialert(obj.UIFig,msg,'No device found','Icon','warning');
            else
                obj.Data=obj.Devlist(:,1:end-1);
                obj.Data.Selected(:)=false;
                obj.UITable.Data=obj.Data;
            end
        end

        function MRefresh(obj,src,evnt)
            RefreshDevlist(obj);
            FillTable(obj);
        end

        function MPickID(obj,src,evnt)
            if ~isempty(evnt.Indices)
                obj.Data.Selected(:)=false;
                obj.RowDevice=evnt.Indices(1);
                obj.Data.Selected(obj.RowDevice)=true;
                obj.UITable.Data=obj.Data;
            end
        end

        function SetVendor(obj,src,evnt)
            if obj.RowDevice>0
                try
                    deviceID = obj.Devlist.DeviceID(obj.RowDevice);
                    vendor = obj.Devlist.DeviceInfo(obj.RowDevice).Vendor.ID;
                    measurementType=obj.Devlist.DeviceInfo(obj.RowDevice).Subsystems.DefaultMeasurementType;
                    d = daq(vendor);
                    addinput(d, deviceID, 1, measurementType);
                catch err
                    uialert(obj.UIFig,sprintf('Could not open the device:\n%s',err.message),...
                        'Device error','Icon','error');
                    return
                end
                SetDevice(obj.Parent.DAQ,d);
                close(obj.UIFig);
                DrawFigure(obj.Parent);
            end
        end


    end
end
