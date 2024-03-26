classdef FieldDouble < Field
    %FIELDDOUBLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        Arr;
        Limits;
        HasLimits;
        Unit;
    end
    
    methods
        function obj = FieldDouble(parent)
            obj@Field(parent);
            obj.Type='double';
            obj.Desc='Simple numeric value with decimal point';
        end
        
        function CheckChange(obj)
            
        end
        
        function var=EmptyCol(obj,count)
            var=cell(count,1);
            for i=1:count
                var{i,1}=0;
            end
%             var=cell(var);
        end
        
        function out=CheckUniformity(obj,arr)
            out=arr;
        end

    end
    
    methods %abstract
        
        function stash=CoPack(obj)
            stash=struct;
        end
        
        
        function CoPopulate(obj,stash)
        end
        
        
        function DrawGui(obj)
            g=uigridlayout(obj.Fig);
            g.RowHeight = {25};
            g.ColumnWidth = {'1x'};
            
            lab1=uilabel(g,'Text',obj.Desc);
            lab1.Layout.Row=1;
            lab1.Layout.Column=1;
        end
        
        function ou=GetOutput(obj)
        end
    end
end

