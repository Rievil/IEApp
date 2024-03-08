classdef FieldString < Field
    %FIELDSTRING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        UnTable;
        UIUnTable;
        IDRow;
    end
    
    properties (Dependent)
        Count;
    end
        
    
    methods
        function obj = FieldString(parent)
            obj@Field(parent);
            obj.Type='string';
            obj.Desc='Can define n classes,\nfor description of each signal';
        end
        
        function count=get.Count(obj)
            count=size(obj.UnTable,1);
        end

        function out=CheckUniformity(obj,arr)
            str=string(arr);
            out=strings(numel(arr),1);
            unqstr=unique(str);
            classes=obj.UnTable.Class;
            
            for i=1:numel(unqstr)
                rows=str==unqstr(i);
                A=contains(classes,unqstr(i));
                if sum(A)==1
                    out(rows)=classes(A);
                else
                    AddMissingLabel(obj);
                    out(rows)="<missing label>";
                end
            end
            out=categorical(out);

        end

        function AddMissingLabel(obj)
            A=obj.UnTable.Class=="<missing label>";
            if sum(A)==0
                obj.UnTable.Class(end+1)="<missing label>";
            end
        end
            
    end
    
    methods %abstract
        function t=GetRow(obj)
            id=obj.Count+1;
            text=string(sprintf('Popis %d',id));
            t=table(text,'VariableNames',{'Class'});
        end
        
        function var=EmptyCol(obj,count)
            var=strings(count,1);
            for i=1:count
                var(i,1)=obj.UnTable.Class(1);
            end
            var=categorical(var);
        end

        function InitTable(obj)
            if isempty(obj.UnTable)
                AddClass(obj);
                obj.UnTable=GetRow(obj);
            end
        end
        
        function AddClass(obj)
            obj.UnTable=[obj.UnTable; GetRow(obj)];
        end
        
        function RemoveClass(obj)
            if obj.Count>0
                obj.UnTable(end,:)=[];
            end
        end
        
        function RefreshTable(obj)
            obj.UIUnTable.Data=obj.UnTable;
        end
        
        function stash=CoPack(obj)
            stash=struct;
            stash.UnTable=obj.UnTable;
        end
        
        function CheckChange(obj)
            
        end
        
        function CoPopulate(obj,stash)
            obj.UnTable=stash.UnTable;    
        end

        
        function out=GetOutput(obj)
            if obj.Count>0
                out=string(obj.UnTable.Class);
            else
                out=strings(0,0);
            end
        end
        
        function DrawGui(obj)
            
            g=uigridlayout(obj.Fig);
            g.RowHeight = {50,25,'1x'};
            g.ColumnWidth = {'1x',75,75};

            lab1=uilabel(g,'Text',sprintf(obj.Desc));
            lab1.Layout.Row=1;
            lab1.Layout.Column=[1 3];

            
            InitTable(obj);
            
            uit=uitable(g,'Data',obj.UnTable,'ColumnEditable',true,'CellSelectionCallback',@obj.MTableRowSelect,...
                'CellEditCallback',@obj.MTableChange);
            uit.Layout.Row=3;
            uit.Layout.Column=[1 3];
            obj.UIUnTable=uit;
            
            but1=uibutton(g,'Text','Add class','ButtonPushedFcn',@obj.MAddClass);
            but1.Layout.Row=2;
            but1.Layout.Column=2;
            
            but2=uibutton(g,'Text','Remove class','ButtonPushedFcn',@obj.MRemoveClass);
            but2.Layout.Row=2;
            but2.Layout.Column=3;
        end
    end
    
    methods %callbacks
        function MAddClass(obj,~,~)
            AddClass(obj);
            RefreshTable(obj);
        end
        
        function MRemoveClass(obj,~,~)
            RemoveClass(obj);
            RefreshTable(obj);
        end
        
        function MTableRowSelect(obj,src,evnt)
            obj.IDRow=evnt.Indices(1);
        end
        
        function MTableChange(obj,~,~)
            obj.UnTable=obj.UIUnTable.Data;
        end
    end
end

