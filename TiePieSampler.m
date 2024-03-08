classdef TiePieSampler < handle
    %TIEPIESAMPLER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Asker;
        SignalStorage;
        Osc;
        DeviceList;
        UITable;
        DeviceListTable table;
        Fig;
        Lib;
        IDSelectedDevice=0;
        SourceFilename char;
        OutFilename char;
        Settings;
    end


    
    properties (Dependent)
        IconFolder;
    end
    
    methods
        function obj = TiePieSampler(~)
            obj.Asker=Asker(obj);
            obj.SignalStorage = SignalStorage(obj);
            obj.Settings=Settings(obj);
            obj.FindDevices;
        end
        
        function folder=get.IconFolder(obj)
            folder = char(strrep(which('TiePieSampler'),'TiePieSampler.m',''));
        end
        
        function FindDevices(obj)
            InitLib(obj);
            
            DrawDeviceSelection(obj);
        end
        
        function SetOscProperties(obj)
            warning('off','all');
            LoadPropertySetup(obj);
            warning('on','all');
        end
        
        
        
        function RefreshAfterLoad(obj)
            if ~isempty(obj.Asker.Fig)
                if isvalid(obj.Asker.Fig)
                    DrawGui(obj.Asker.Marker);
%                     CheckMeasuredSignals(obj.Asker.Marker);
                    RefreshSignalTable(obj.Asker);
                end
            end
        end
        
        
        function StartAsker(obj)
            obj.Asker.setOsciloscope(obj.Osc);
            obj.Asker.StartReading;
        end
        
        function delete(obj)
            delete(obj.Osc);
            delete(obj.Lib);
            delete(obj.Asker);
            disp('All TiePie procedures were canceled');
        end
        
        
    end
    
    methods
        function SaveMeas(obj)
            if numel(obj.OutFilename)<2
                [file,path] = uiputfile('animinit.mat');
                if exist(path)
                    obj.OutFilename=[path, file];
                else
                    clear obj.OutFilename;
                end
            else
                txt=sprintf('Measuremnet already has a output file, do you want to save data into same file: %s ?',obj.OutFilename);
                selection = uiconfirm(obj.Asker.Fig,txt,'Overwrite measurement?',...
            'Icon','warning');
                switch selection
                    case 'OK'
                    otherwise
                    [file,path] = uiputfile('animinit.mat');
                    obj.OutFilename=[path, file];
                end
            end
            message = sprintf('Saving measurement on path:%s',obj.OutFilename);
            d = uiprogressdlg(obj.Asker.Fig,'Title',message,'Indeterminate','on');
    
            
%             uialert(,message,'Warning',...
%             'Icon','info');
            if numel(obj.OutFilename)>2
                stash=Pack(obj);
                
                save(obj.OutFilename,'stash');
                obj.SourceFilename=obj.OutFilename;
            end
            close(d);
            
            uialert(obj.Asker.Fig,'Meas succesfully saved','Success','Icon','success');
%             close(message);
        end
        
        function LoadMeas(obj)
            [file,path] = uigetfile('*.mat');
            obj.SourceFilename=[path, file];

            load(obj.SourceFilename);

            if exist('stash','var')
                obj.Populate(stash);
                
                RefreshAfterLoad(obj);
                obj.OutFilename=obj.SourceFilename;
            else
                disp('This variable doesnt contain any TiePieSampler data');
            end
        end
        
        function ChangeSettings(obj)
            obj.Osc.stop();
            LoadPropertySetup(obj);
        end
    end
    
    methods (Access = private)
        function DrawDeviceSelection(obj)
            obj.IDSelectedDevice=0;
            Pix_SS = get(0,'screensize');
            A=900;
            B=400;
            dim=[Pix_SS(3)/2-A/2,Pix_SS(4)/2-B/2,A,B];
            
            obj.Fig=uifigure('position',dim);
            
            g=uigridlayout(obj.Fig);
            g.RowHeight={25,'1x',25};
            g.ColumnWidth={'1x',150,150};
            
            lab1=uilabel(g,'Text','Select device to connect:');
            lab1.Layout.Row=1;
            lab1.Layout.Column=[1 3];
            
            uit=uitable(g,'Data',obj.DeviceListTable,'CellSelectionCallback',@obj.MRowSelected);
            uit.Layout.Row=2;
            uit.Layout.Column=[1 3];
            
            obj.UITable=uit;
            
            but1=uibutton(g,'Text','Select device','ButtonPushedFcn',@obj.MSelectDevice);
            but1.Layout.Row=3;
            but1.Layout.Column=2;
            
            but2=uibutton(g,'Text','Cancle and exit','ButtonPushedFcn',@obj.MExit);
            but2.Layout.Row=3;
            but2.Layout.Column=3;            

            but3=uibutton(g,'Icon',[obj.IconFolder,'Master\Icons\Refresh_Logo.gif'],...
                'Text','List devices','ButtonPushedFcn',@obj.MRefresh);

            but3.Layout.Row=1;
            but3.Layout.Column=3;   
        end
        
        function ConnectToDevice(obj)
            delete(obj.Osc);
            clear obj.Osc;
            k = obj.IDSelectedDevice-1;
            item = obj.Lib.DeviceList.getItemByIndex(k);
            if item.canOpen(DEVICETYPE.OSCILLOSCOPE)
                obj.Osc = item.openOscilloscope();
            end
            LoadPropertySetup(obj);
        end
        
        function LoadPropertySetup(obj)
            
            obj.Osc.MeasureMode = MM.BLOCK;

            duration=obj.Settings.Duration;
            samples=duration*obj.Settings.SampFreq;
            % Set sample frequency:
            obj.Osc.SampleFrequency = obj.Settings.SampFreq; % 1 kHz
            
            % Set record length:
            obj.Osc.RecordLength = samples; % 1 kS
            % scp.PreSampleRatio = 10;
            
            % For all channels:
            for ch = obj.Osc.Channels
                % Enable channel to measure it:
                ch.Enabled = true;
            
                % Set range:
                ch.Range = obj.Settings.VoltRange; % 8 V
            
                % Set coupling:
                ch.Coupling = CK.ACV; % DC Volt
            
                clear ch;
            end

            obj.Osc.Resolution=obj.Settings.Resolution;
            clear chTr;
        end

        function InitLib(obj)
            
            obj.Lib=Library;
            

            % Enable network search:       
            obj.Lib.Network.AutoDetectEnabled = true;

            % Update device list:
            obj.Lib.DeviceList.update();

            % Get the number of connected devices:
            numDevices = obj.Lib.DeviceList.Count;
            obj.DeviceListTable=table;
            
            if numDevices > 0
%                 fprintf('Available devices:\n');
                
                for k = 0 : numDevices - 1
                    item = obj.Lib.DeviceList.getItemByIndex(k);
                    
%                     fprintf('  Name: %s\n', item.Name);
%                     fprintf('    Serial Number  : %u\n', item.SerialNumber);
%                     fprintf('    Available types: %s\n', ArrayToString(item.Types));
                    if item.HasServer
                        hasServer=true;
                        URL=string(server.URL);
                        serverName=string(server.Name);
                        clear server
                    else
                        hasServer=false;
                        URL="-";
                        serverName="-";
                        
                    end
                    
                    T=table(string(item.Name),string(item.SerialNumber),...
                        string(ArrayToString(item.Types)),hasServer,URL,serverName,...
                        'VariableNames',{'DeviceName','SerialNumber','AvailableType','HasServer','ServerURL','ServerName'});
                    clear item;
                    
                    obj.DeviceListTable=[obj.DeviceListTable; T];
                end
            else
%                 fprintf('No devices found!\n')
            end

        end
        
        function stash=Pack(obj)
            stash=struct;
            
            TMP=Pack(obj.Asker);
            stash.Asker=TMP;
            
            TMP2=Pack(obj.SignalStorage);
            stash.SignalStorage=TMP2;
            
            stash.OutFilename=obj.OutFilename;
            stash.SourceFilename=obj.SourceFilename;
            stash.Settings=obj.Settings.Pack;
            
            

        end
        
        function Populate(obj,stash)
            obj.Asker.Populate(stash.Asker);
            obj.SignalStorage.Populate(stash.SignalStorage);
            obj.SourceFilename=stash.SourceFilename;
            obj.Settings.Populate(stash.Settings);
        end
        
        
        

    end
    
    methods %callbacks
        function MRowSelected(obj,src,envt)
            row=envt.Indices(1);
            obj.IDSelectedDevice=row;
        end

        function MRefresh(obj,src,evnt)
            d = uiprogressdlg(obj.Fig,'Title','Please Wait',...
        'Message','Listing TiePie devices ...','Indeterminate','on');
            InitLib(obj);
            obj.UITable.Data=obj.DeviceListTable;
            close(d);
        end
        
        function MSelectDevice(obj,~,~)
            if obj.IDSelectedDevice>0 && obj.IDSelectedDevice<=obj.Lib.DeviceList.Count
                ConnectToDevice(obj);
                delete(obj.Fig);
                StartAsker(obj);
            else
                %nothing yet selected
            end
        end
        
        function MExit(obj,~,~)
            delete(obj.Fig);
        end
        
    end
end

