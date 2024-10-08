classdef Asker < handle
    %ASKER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Fig;
        Parent;
        DAQ;
        Grid;
        Ax;
        AxFFT;
        UISignalParamPanel;
        Timer;
        IsRunning=false;
        Osc;
        IsDrawed=false;
        ArrData;
        UIStatLabel;
        UISignalTable;
        UISwitch;
        SignalsTable table;
        
        CurrSignal table;
        TMPCurrSignal table;
        UIMemButton;
        Marker;
        Plotter;
        FigDim=[1200,600];
        Settings;
        ID=0;
        InterruptDialog;
        MyListener;
        OutFilename='';
        SourceFilename;
        PickDevice;
        TemplateName='Default';
    end
    
    properties (Dependent)
        Count;
        IsFig;
        CurrIDSel;
    end
    
    properties (Hidden)
        TSignalRow=0;
        LockLabels='2';
        UIStartStop;
        IF='App\Icons\';
        UITemplateField;
    end


    
    methods
        function obj = Asker()
            obj.DAQ=MyDAQ(obj);
            obj.Marker = Marker(obj);
            obj.Plotter=Plotter(obj);
            obj.PickDevice=PickDevice(obj);
            obj.Settings=Settings(obj);

            InitMarker(obj.Marker);
            obj.MyListener=addlistener(obj.DAQ,'SignalReady',@obj.GetData);
            DrawGUI(obj.PickDevice);
        end


        
        
        function id=get.CurrIDSel(obj)
            id=obj.TSignalRow;
        end
        
        function set.CurrIDSel(obj,id)
            obj.TSignalRow=id;
            
        end

        function data=ReadStream(obj)

        end
        
        
        
        function setOsciloscope(obj)
            obj.DAQ=MyDAQ(obj);
        end

        function state=get.IsFig(obj)
            if ~isempty(obj.Fig)
                if isvalid(obj.Fig)
                    state=true;
                else
                    state=false;
                end
            else
                 state=false;
            end
        end
        
        function count=get.Count(obj)
            count=size(obj.SignalsTable,1);
        end

        
        function StopReading(obj)
            obj.DAQ.stop;
            obj.DAQ.State='off';
            obj.UIStartStop.Icon=[obj.IF 'StartMeas.gif'];
            obj.UIStartStop.Tooltip='Start measurment (s)';
        end
        

        
        function CheckRunning(obj,src,~)
            disp('Started asking Osc for data');
        end
        
        function CloseCheck(obj,src,~)
            disp('Stopped asking for data');
%             stop(obj.Osc);
        end
        
        function StartReading(obj)
           obj.DAQ.start;
           obj.DAQ.State='on';
           obj.UIStartStop.Icon=[obj.IF 'StopMeas.gif'];
           obj.UIStartStop.Tooltip='Stop measurment (s)';
        end

        
        function T=SetTable(obj)
            T=table();
        end
        
        function AddSignal(obj)
            if ~isempty(obj.CurrSignal)
                obj.ID=obj.ID+1;
                if size(obj.SignalsTable,1)==0
                    obj.SignalsTable=table();
                end
                obj.CurrSignal=obj.TMPCurrSignal;
                obj.CurrSignal.ID=obj.ID;
                obj.SignalsTable=[obj.SignalsTable; obj.CurrSignal];
                obj.Marker.AddDescription;
                RefreshSignalTable(obj);

                obj.TMPCurrSignal=[];
                CheckMemButton(obj);
                RefreshSignalTable(obj);
            end
        end
        
        function RefreshSignalTable(obj)
            obj.UISignalTable.Data=obj.Marker.DescTable;
            if size(obj.UISignalTable.Data,1)>0
                edit_bool=zeros(1,size(obj.UISignalTable.Data,2));
                for n=1:size(obj.UISignalTable.Data,2)
                    if n>1
                        edit_bool(n)=true;
                    else
                        edit_bool(n)=false;
                    end
                end
                obj.UISignalTable.ColumnEditable=logical(edit_bool);
            end
            opt={25};
            count=size(obj.Marker.DescTable,2);
            for i=1:count
                opt{i+1}="auto";
            end
            obj.UISignalTable.ColumnWidth=opt;
        end
        
        
        function RemoveSignal(obj)
            if ~isempty(obj.SignalsTable)
                if obj.CurrIDSel>0
                    obj.Marker.DescTable(obj.CurrIDSel,:)=[];
                    obj.SignalsTable(obj.CurrIDSel,:)=[];
                    obj.CurrIDSel=0;
                else
                    obj.SignalsTable(end,:)=[];
                    obj.Marker.DescTable(end,:)=[];
                end
            end
            RefreshSignalTable(obj);
        end

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
                selection = uiconfirm(obj.Fig,txt,'Overwrite measurement?',...
            'Icon','warning');
                switch selection
                    case 'OK'
                    otherwise
                    [file,path] = uiputfile('animinit.mat');
                    obj.OutFilename=[path, file];
                end
            end
            message = sprintf('Saving measurement on path:%s',obj.OutFilename);
            d = uiprogressdlg(obj.Fig,'Title',message,'Indeterminate','on');
    
            
%             uialert(,message,'Warning',...
%             'Icon','info');
            if numel(obj.OutFilename)>2
                stash=Pack(obj);
                
                save(obj.OutFilename,'stash');
                obj.SourceFilename=obj.OutFilename;
            end
            close(d);
            
            uialert(obj.Fig,'Meas succesfully saved','Success','Icon','success');
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

        function RefreshAfterLoad(obj)
            if ~isempty(obj.Fig)
                if isvalid(obj.Fig)
                    DrawGui(obj.Marker);
%                     CheckMeasuredSignals(obj.Asker.Marker);
                    RefreshSignalTable(obj);
                end
            end
        end
                
        function DrawFigure(obj)
            Pix_SS = get(0,'screensize');

            dim=[Pix_SS(3)/2-obj.FigDim(1)/2,Pix_SS(4)/2-obj.FigDim(2)/2,obj.FigDim(1),obj.FigDim(2)];
            obj.Fig=uifigure('Position',dim,'CloseRequestFcn',@obj.MFigClosed,'WindowKeyPressFcn',@obj.MKeyCallback,...
                'WindowStyle','normal');

            g=uigridlayout(obj.Fig);
            g.RowHeight = {25,100,'1x',25};
            g.ColumnWidth = {100,200,'1x',250};
            
            tb = uitoolbar(obj.Fig);
            % obj.IF='App\Icons\';
            
            pt0 = uipushtool(tb,'Icon',[obj.IF 'StartMeas.gif'],'Tooltip','Start measurment (s)','ClickedCallback',@obj.MStartStopMeasurment);
            pt1 = uipushtool(tb,'Icon',[obj.IF 'SavingIcon.gif'],'Tooltip','Save measurement','ClickedCallback',@obj.MSaveMeas);
            pt2 = uipushtool(tb,'Icon',[obj.IF 'LoadMeas.gif'],'Tooltip','Load measurement','ClickedCallback',@obj.MLoadMeas);
            pt3 = uipushtool(tb,'Icon',[obj.IF 'Settings.gif'],'Tooltip','Settings','ClickedCallback',@obj.MChangeSettings);
            obj.UIStartStop=pt0;

            lab=uilabel(g,'Text','Template:');
            lab.Layout.Row=1;
            lab.Layout.Column=1;
            obj.UIStatLabel=lab;

            uid2=uieditfield(g,"text",'ValueChangedFcn',@obj.MTemplateNameChange,'Value',obj.TemplateName);
            uid2.Layout.Row=1;
            uid2.Layout.Column=2;
            obj.UITemplateField=uid2;
            
            swit=uiswitch(g,'Items',{'Automatic save','Manual save'},'ItemsData',{1,0});
            swit.Layout.Row=1;
            swit.Layout.Column=3;
            obj.UISwitch=swit;
            
            
            
            
            if isempty(obj.SignalsTable)
                obj.SignalsTable=SetTable(obj);
            end
            
            uit=uitable(g,'CellSelectionCallback',@obj.MSignalSelect,'CellEditCallback',@obj.MSignalTableEditDesc);
            uit.Layout.Row=[2 3];
            uit.Layout.Column=[1 2];
            obj.UISignalTable=uit;
            RefreshSignalTable(obj);
            
            but=uibutton(g,'Text','Show signal from memory','ButtonPushedFcn',@obj.MShowMemorySignal);
            but.Layout.Row=1;
            but.Layout.Column=4;
            
            obj.UIMemButton=but;
            CheckMemButton(obj);
            
            p=uipanel(g,'Title','Signal description');
            p.Layout.Row=[3 4];
            p.Layout.Column=4;
            
            obj.Marker.SetFig(p);
            obj.Marker.DrawGui;
            
            obj.Grid=g;
            
            
            
            
            p=uipanel(g);
            p.Layout.Row=[2 4];
            p.Layout.Column=3;
            
            but3=uibutton(g,'Text','Remove signal (del)','ButtonPushedFcn',@obj.MRemoveSignal);
            but3.Layout.Row=4;
            but3.Layout.Column=[1 2];

            g3=uigridlayout(p);
            g3.RowHeight={'3x','2x'};
            g3.ColumnWidth={'2x','1x'};
            ax=uiaxes(g3);
            
            ax.Layout.Row=1;
            ax.Layout.Column=[1 2];
            obj.Ax=ax;
            
            ax2=uiaxes(g3);
            ax2.Layout.Row=2;
            ax2.Layout.Column=1;
            obj.AxFFT=ax2;
            
            p3=uipanel(g3,'Title','Signal parameters');
            p3.Layout.Row=2;
            p3.Layout.Column=2;
            
            obj.UISignalParamPanel=p3;
            obj.DAQ.DrawGUI(p3);

            p2=uipanel(g,'Title','Control panel');
            p2.Layout.Row=2;
            p2.Layout.Column=4;
            
            g2=uigridlayout(p2);
            g2.RowHeight = {25,25};
            g2.ColumnWidth = {'1x','1x','1x'};
            
            but1=uibutton(g2,'Text','Edit marker (Ctrl+m)','ButtonPushedFcn',@obj.MEditMarker);
            but1.Layout.Row=1;
            but1.Layout.Column=1;
            
            but2=uibutton(g2,'Text','Add signal (space)','ButtonPushedFcn',@obj.MAddSignal);
            but2.Layout.Row=1;
            but2.Layout.Column=[2 3];

            uitsw=uiswitch(g2,'Items',{'Lock Label','Current Label'},'ItemsData',{'1','2'},'ValueChangedFcn',@obj.MLabelSwitch);
            uitsw.Value=obj.LockLabels;
            SetLockLabels(obj);

            uitsw.Layout.Row=2;
            uitsw.Layout.Column=[1 3];

            SetControls(obj.Plotter);
        end
        
        function CheckMemButton(obj)
            if ~isempty(obj.TMPCurrSignal)
                obj.UIMemButton.Enable='on';
            else
                obj.UIMemButton.Enable='off';
            end
        end

        function MSignalTableEditDesc(obj,src,evnt)
            obj.Marker.DescTable=obj.UISignalTable.Data;
        end
        
        function MStartStopMeasurment(obj,src,envt)
            StartStopCheck(obj);
        end

        function StartStopCheck(obj)
            switch obj.DAQ.State
                case 'on'
                    StopReading(obj);
                case 'off'
                    StartReading(obj);
            end
        end

        function MChangeSettings(obj,src,evnt)
            if obj.Settings.FigBool==false
              obj.Settings.DrawGui;
            end
        end
        
        function MAddSignal(obj,src,~)
            AddSignal(obj);
        end
        
        function SetLockLabels(obj)
            switch obj.LockLabels
                case '1'
                    obj.Marker.LockLabels;
                case '2'
                    obj.Marker.UnlockLabels;
            end
        end

        function MLabelSwitch(obj,src,~)
            obj.LockLabels=src.Value;
            SetLockLabels(obj);
        end


        function MSignalSelect(obj,src,evnt)
            if ~isempty(evnt.Indices)
                obj.CurrIDSel=evnt.Indices(1);
                id=obj.SignalsTable.ID(obj.CurrIDSel);
                if obj.LockLabels=='2'
                    obj.Marker.ShowDescription(id);
                end
                row=find(obj.SignalsTable.ID==id,1);
                obj.CurrSignal=obj.SignalsTable(row,:);
                obj.Plotter.ShowSignal;
            end
        end
        
        function MRemoveSignal(obj,src,~)
            RemoveSignal(obj);
        end
        
        function MKeyCallback(obj,src,evnt)
            
            switch lower(evnt.Key)
                case 'space'
                    if obj.UISwitch.Value==false
                        if ~isempty(obj.TMPCurrSignal)
                            AddSignal(obj);
                        end
                    end
                case 'delete'
                    msg=sprintf('Delete signal ID: %d ?',obj.SignalsTable.ID(obj.CurrIDSel));
                    selection = uiconfirm(obj.Fig,msg,'Delete signal',...
                    'Icon','warning');
                    switch selection
                        case 'OK'
                            RemoveSignal(obj);
                        otherwise
                    end
                case 'numpad0'
                    disp('numpad0');
                case 'numpad1'
                    disp('numpad1');
                case 'numpad2'
                    disp('numpad2');
                case 'numpad3'
                    disp('numpad3');
                case 'numpad4'
                    disp('numpad4');
                case 'numpad5'
                    disp('numpad5');
                case 'numpad6'
                    disp('numpad6');
                case 'numpad7'
                    disp('numpad7');
                case 'numpad8'
                    disp('numpad8');
                case 'numpad9'    
                    disp('numpad9');
                case 's'
                    StartStopCheck(obj);
            end
        end
        
        function MLoadMeas(obj,~,~)
            obj.LoadMeas;
        end
        
        function MSaveMeas(obj,~,~)
            obj.SaveMeas;
        end
        
        function MEditMarker(obj,~,~)
%             obj.Fig.Enable='off';
            
            if obj.Count>0
                selection = uiconfirm(obj.Fig,'Edit of markers will replace current description','Edit markers?',...
                    'Icon','warning');
                switch selection
                    case 'OK'
                        ShowSelection(obj.Marker);
                    otherwise
                end
            else
                ShowSelection(obj.Marker);
            end
            obj.Fig.Visible = 'off';
        end
        
        function MShowMemorySignal(obj,~,~)
            if ~isempty(obj.TMPCurrSignal)
                obj.CurrSignal=obj.TMPCurrSignal;
                obj.Plotter.ShowSignal;
            end
        end

        function MTemplateNameChange(obj,src,evnt)
            obj.TemplateName=src.Value;
        end
        
        
        function MFigClosed(obj,~,~)
            StopReading(obj);
            delete(obj.Fig);
        end
        
        function GetData(obj,src,evtdata)
            % obj.ID=obj.ID+1;

            obj.CurrSignal = obj.DAQ.AcData;
            obj.CurrSignal.ID=0;
            obj.TMPCurrSignal=obj.CurrSignal;
            CheckMemButton(obj);
            

            if obj.UISwitch.Value==1
                AddSignal(obj);
            else
                obj.CurrIDSel=0;
            end

            obj.Plotter.ShowSignal;
        end
        
        function PlotOsc(obj)
            cla(obj.Ax);
            hold(obj.Ax,'on');
            signal=obj.CurrSignal.Signals{1};
            time=linspace(obj.CurrSignal.StartTiem,obj.CurrSignal.EndTime,obj.CurrSignal.Samples)';
            plot(obj.Ax,time,signal,'DisplayName',sprintf('Mic ID:%d',obj.CurrSignal.ID));
            legend(obj.Ax);
            obj.IsDrawed=true;
        end
        
        function delete(obj)
            clear obj.Osc;
        end
        
        function stash=Pack(obj)
            stash=struct;
            stash.CurrIDSel=obj.CurrIDSel;
            stash.SignalsTable=obj.SignalsTable;
            stash.ID=obj.ID;
            stash.LockLabels=obj.LockLabels;
            stash.DAQ=Pack(obj.DAQ);
            stash.UISwitchState=obj.UISwitch.Value;
            stash.TemplateName=obj.TemplateName;
            TMP=Pack(obj.Marker);
            
            stash.Marker=TMP;
        end
        
        function Populate(obj,stash)
            proplist=["CurrIDSel","SignalsTable","Marker","ID","LockLabels","DAQ","UISwitchState","TemplateName"];
            for field=proplist
                if isfield(stash,field)
                    switch field
                        case 'Marker'
                            obj.(field).Populate(stash.(field));
                        case 'UISwitchState'
                            obj.UISwitch.Value=stash.(field);
                        case 'DAQ'
                            obj.(field).Populate(stash.(field));
                        case 'TemplateName'
                            obj.(field)=stash.(field);
                            obj.UITemplateField.Value=obj.(field);
                        otherwise
                            obj.(field)=stash.(field);
                    end
                end
            end
        end
        
    end
end

