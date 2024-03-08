classdef SignalStorage < Module
    %SIGNALSAVER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        DBFolder=':C\';
        DBFilename;
        Name='project1';
        IsInit=false;
        NSignal;
        NDescription;
        SignalTable;
        SignalDescriptionTable;
        OutTable;
        UIFolder;
    end
    
    methods
        function obj = SignalStorage(parent)
            obj@Module(parent);

        end
        
        function SetName(obj)
           if exist(obj.DBFolder)
              obj.DBFilename=[char(obj.DBFolder),'\',char(obj.Name),'.db'];
           end
        end
        
        function SetFolder(obj)
            selpath = uigetdir(cd,'Select folder for saving .db file');
            obj.DBFolder=selpath;
        end
        
        function InitDB(obj)
            if obj.IsInit==false
                DrawGui(obj);
            else
                

            end
        end
        
        function CreateDB(obj)
%             dbfile = fullfile(pwd,obj.DBFilename);
            if exist(obj.DBFilename)
                conn = sqlite(obj.DBFilename,'connect');
                
            else
                conn = sqlite(obj.DBFilename,'create');
            end
            obj.IsInit=true;
            
        end

    end
    
    methods %Abstract)
        function stash=Pack(obj)
            stash=struct;
        end
        
        function Populate(obj,stash)
        end
        
        function DrawGui(obj)
            Pix_SS = get(0,'screensize');
            A=800;
            B=150;
            dim=[Pix_SS(3)/2-A/2,Pix_SS(4)/2-B/2,A,B];
            
            obj.Fig=uifigure('position',dim);
            g=uigridlayout(obj.Fig);
            g.RowHeight={25,25,25};
            g.ColumnWidth={85,'1x',25};
            
            lab1=uilabel(g,'Text','Select name');
            lab1.Layout.Row=1;
            lab1.Layout.Column=1;
            
                        
            lab2=uilabel(g,'Text','Select folder');
            lab2.Layout.Row=2;
            lab2.Layout.Column=1;
            
            edf1= uieditfield(g,'text','Value','project1','ValueChangedFcn',@obj.MChangeName);
            edf1.Layout.Row=1;
            edf1.Layout.Column=2;
            
            edf2= uieditfield(g,'text','Value','C:\');
            edf2.Layout.Row=2;
            edf2.Layout.Column=2;
            obj.UIFolder=edf2;
            
            but1=uibutton(g,'Text','select folder','ButtonPushedFcn',@obj.MSetFolder);
            but1.Layout.Row=2;
            but1.Layout.Column=3;
            
            but2=uibutton(g,'Text','Create db file','ButtonPushedFcn',@obj.MCreateDBFile);
            but2.Layout.Row=3;
            but2.Layout.Column=[1 3];
        end
        
        function MSetFolder(obj,src,~)
            SetFolder(obj);
            SetName(obj);
            obj.UIFolder.Value=obj.DBFilename;
        end
        
        function MChangeName(obj,src,~)
            obj.Name=src.Value;
            SetName(obj);
            obj.UIFolder.Value=obj.DBFilename;
        end
        
        function MCreateDBFile(obj,src,~)
            CreateDB(obj);
            if obj.IsInit==true
                delete(obj.Fig);
            end
        end
    end
end

