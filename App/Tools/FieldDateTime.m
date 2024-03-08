classdef FieldDateTime < Field
    %FIELDDATETIME Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        DateTime;
        Format;
        State=false;
    end
    
%     properties (Dependent)
%         Count;
%     end
    
    methods
        function obj = FieldDateTime(parent)
            obj@Field(parent);
            obj.Type='datetime';
            obj.Desc='Can select current or specific\ndate and time for each signal';
        end

    end
    
    methods %abstract
        function stash=CoPack(obj)
            stash=struct;
        end
        
        function CheckChange(obj)
            
        end

        function var=EmptyCol(obj,count)
            for i=1:count
                var(i,1)=datetime(now(),'ConvertFrom','datenum','Format','dd.MM.yyyy hh:mm:ss.ss');
            end
        end

        function out=CheckUniformity(obj,arr)
            out=arr;
        end
        
        function CoPopulate(obj,stash)
        end
        
        function DrawGui(obj)
            g=uigridlayout(obj.Fig);
            g.RowHeight = {25};
            g.ColumnWidth = {'1x'};
            lab1=uilabel(g,'Text',sprintf(obj.Desc));
            lab1.Layout.Row=1;
            lab1.Layout.Column=1;
        end
        
        function ou=GetOutput(obj)
        end
    end
end

