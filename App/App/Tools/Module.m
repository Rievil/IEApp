classdef Module < handle
    %MODULE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties

        Parent;
        Fig;
        FigBool=false;
    end
    
    methods
        function obj = Module(parent)
            obj.Parent=parent;

        end
        
        function SetFig(obj,fig)
            obj.Fig=fig;
%             fig.CloseRequestFcn=@obj.MClearGui;
            obj.FigBool=true;
        end
        
        function ClearGui(obj)
            if obj.FigBool==true
                a=obj.Fig.Children;
                a.delete;
            end
        end
        
        function MClearGui(obj,~,~)
            ClearGui(obj);
        end
        

    end
    
    methods (Abstract)
        Pack
        Populate
        DrawGui
    end
end


