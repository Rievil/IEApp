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

        function Osc=SetOsciloscope(obj,type)

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
            fig=uifigure('CloseRequestFcn',@obj.MCloseFig);
            obj.SetFig(fig);
            g=uigridlayout(obj.Fig);
            g.RowHeight = {25,25,25,25,25};
            g.ColumnWidth = {120,120,'1x'};
            
            %lab=uilabel(grid,'Text',char(obj2.Name),'BackgroundColor',[0.7 0.7 0.7],'HorizontalAlignment','left');
            
            lab1=uilabel(g,'Text','Select settings for Osciloscope');
            lab1.Layout.Row=1;
            lab1.Layout.Column=[1 2];
            
            %uit=uitable(g,'Data',);
            lab2=uilabel(g,'Text','Sampling frequency:');
            lab2.Layout.Row=2;
            lab2.Layout.Column=[1 2];
            
            drop1=uidropdown(g,'Items',["3 Hz","50 Hz","1 kHz","20 kHz","48 kHz","200 kHz","500 kHz","1 MHz","5 MHz"],...
                'ItemsData',[3,50,1e+3,20e+3,48e+3,200e+3,500e+3,1e+6,5e+6],...
                'Value',obj.SampFreq,'ValueChangedFcn',@obj.MSamplingFreq);
            drop1.Layout.Row=2;
            drop1.Layout.Column=3;
            
            lab3=uilabel(g,'Text','Volt Range:');
            lab3.Layout.Row=3;
            lab3.Layout.Column=[1 2];
            
            drop2=uidropdown(g,'Items',["2 V","4 V","8 V","20 V"],...
                'ItemsData',[2,4,8,20],...
                'Value',obj.VoltRange,'ValueChangedFcn',@obj.MVoltRange);
            drop2.Layout.Row=3;
            drop2.Layout.Column=3;
            
            lab4=uilabel(g,'Text','Treashold voltage:');
            lab4.Layout.Row=4;
            lab4.Layout.Column=[1 2];
            
            edt1=uieditfield(g,'numeric','Limits', [0,100],...
                      'LowerLimitInclusive','off',...
                      'UpperLimitInclusive','on',...
                      'Value', obj.TrshVolt,'ValueChangedFcn',@obj.MTrshVolt);
            edt1.Layout.Row=4;
            edt1.Layout.Column=3;
            
            lab4=uilabel(g,'Text','Hystereses:');
            lab4.Layout.Row=5;
            lab4.Layout.Column=[1 2];
            
            edt2=uieditfield(g,'numeric','Limits', [0,100],...
                      'LowerLimitInclusive','off',...
                      'UpperLimitInclusive','on',...
                      'Value', obj.TrshHystereses,...
                      'ValueChangedFcn',@obj.MTrshHystereses);
            edt2.Layout.Row=5;
            edt2.Layout.Column=3;
            
            
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
            obj.ClearGui;
            delete(obj.Fig);
            obj.Parent.ChangeSettings;
            
        end
    end
end

