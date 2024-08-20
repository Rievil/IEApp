classdef Settings < Module
    %SETTINGS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        SampFreq=100e+3;
        VoltRange=4;
        TrshVolt=1.5;
        TrshHystereses=1;
        Duration=1;
        Resolution=16;
        Osc;
    end
    
    methods
        function obj = Settings(parent)
            obj@Module(parent);
        end

    end
    
    methods %abstract
        function stash=Pack(obj)
            stash=struct;
            stash.SampFreq=obj.SampFreq;
            stash.VoltRange=obj.VoltRange;
            stash.TrshVolt=obj.TrshVolt;
            stash.TrshHystereses=obj.TrshHystereses;
        end
        
        function Populate(obj,stash)
            obj.SampFreq=stash.SampFreq;
            obj.VoltRange=stash.VoltRange;
            obj.TrshVolt=stash.TrshVolt;
            obj.TrshHystereses=stash.TrshHystereses;
        end
        
        function DrawGui(obj)
            obj.FigBool=true;
            fig=uifigure('CloseRequestFcn',@obj.MCloseFig);
            obj.SetFig(fig);
            g=uigridlayout(obj.Fig);
            
            g.RowHeight = {'1x'};
            g.ColumnWidth = {'1x'};

            tg = uitabgroup(g);
            t3 = uitab(tg,"Title","Marker");
            obj.Parent.Marker.DrawSettings(t3);

            t1 = uitab(tg,"Title","Plotter");

            t2 = uitab(tg,"Title","DAQ");



        end
        
    end
    
    methods %callbacks
        function MSamplingFreq(obj,src,~)
            obj.SampFreq=src.Value;
        end
        
        function MVoltRange(obj,src,~)
            obj.VoltRange=src.Value;
        end
        
        function MTrshVolt(obj,src,~)
            obj.TrshVolt=src.Value;
        end
        
        function MTrshHystereses(obj,src,~)
            obj.TrshHystereses=src.Value;
        end
        
        function MCloseFig(obj,~,~)
            obj.FigBool=false;
            obj.ClearGui;
            delete(obj.Fig);
        end
    end
end

