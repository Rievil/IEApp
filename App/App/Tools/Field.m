classdef Field < Module
    %FIELD Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Type;
        Name;
        Desc;
    end
    
    properties (Dependent)
        OutUnq;
    end
    
%     properties (Abstract,Dependent)
%         Count;
%     end
    

    
    methods
        function obj = Field(parent)
            obj@Module(parent);
            

        end
        
        function outunq=get.OutUnq(obj)
            outunq=GetOutput(obj);
        end
        
        function stash=Pack(obj)
            stash=struct;
            stash.Type=obj.Type;
            stash.Name=obj.Name;
            TMP=CoPack(obj);
            stash.Specific=TMP;
        end
        
        function Populate(obj,stash)
            obj.Type=stash.Type;
            obj.Name=stash.Name;
            
            obj.CoPopulate(stash.Specific);
        end
        
        function AlterField(obj)
            CheckChange(obj);
        end 
        
    end
    
    methods (Abstract)
        GetOutput;
        CoPack;
        CoPopulate;
        CheckChange;
        EmptyCol;
        CheckUniformity;
    end
end

