classdef Plotter < Module
    %PLOTTER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        UIAx;
        UIAxFFT;
        UIStatePanel;
        UILamp;
        UIHammerOver;
        UISensorOver;
        UIRollAngle;
        TMPSignal;
        SigOvr;
        ReadGyroBool='0';
        CurrID;
    end
    
    properties (Dependent)
        IsFig;
    end
    
    methods
        function obj = Plotter(parent)
            obj@Module(parent);
        end
        
        function state=get.IsFig(obj)
            state=false;
            if ~isempty(obj.Parent.Fig)
                if isvalid(obj.Parent.Fig)
                    state=true;
                end
            end
        end
        
        function SetControls(obj)
            obj.UIAx=obj.Parent.Ax;
            obj.UIAxFFT=obj.Parent.AxFFT;
            obj.Fig=obj.Parent.UISignalParamPanel;
            LabelAxes(obj);
        end
        
        function LabelAxes(obj)
            if obj.IsFig
                
                hold(obj.UIAx,'on');
                
                xlabel(obj.UIAx,'Time \it t \rm [s]');
                ylabel(obj.UIAx,'Amplitude \it A \rm [V]');
                
                
                hold(obj.UIAxFFT,'on');
                xlabel(obj.UIAxFFT,'Frequency \it f \rm [Hz]');
                ylabel(obj.UIAxFFT,'Amplitude \it A \rm [V]');
                
                % DrawGui(obj);
            end
        end

    end
    
    methods
        
        function ShowSignal(obj)
            GetSignal(obj);
            PlotOsc(obj);
            PlotFFT(obj);
        end
        
        function GetSignal(obj)
            obj.TMPSignal=obj.Parent.CurrSignal;
            obj.CurrID=obj.TMPSignal.ID(1);
        end

        function PlotArduino(obj)
            ard=obj.Parent.Arduino;
            gyro=obj.Parent.Gyro;
            [pitch,roll]=GetRoll(gyro,ard,obj.CurrID);
            obj.UIRollAngle.Text=sprintf("Roll: %0.2f ° Pitch: %0.2f°",roll,pitch);
        end
        
        function PlotOsc(obj)
            cla(obj.UIAx);
            time=linspace(obj.TMPSignal.StartTime,obj.TMPSignal.EndTime,obj.TMPSignal.Samples)';
            y1=obj.TMPSignal.Signal{1};
            
            
            if obj.Parent.UISwitch.Value==1 || sum(obj.Parent.Marker.DescTable.ID==obj.TMPSignal.ID(1))>0
                mark=obj.Parent.Marker;
                label=GetLabel(mark,obj.TMPSignal.ID(1));
            else
                 label='Signal in memory';
            end

            title(obj.UIAx,label);
            plot(obj.UIAx,time,y1,'DisplayName','Microphone');
            xlim(obj.UIAx,[time(1),time(end)]);
            obj.SigOvr=[max(y1)-min(y1)];
            
            legend(obj.UIAx);
        end
        
        function PlotFFT(obj)
            cla(obj.UIAxFFT);

            y1o=obj.TMPSignal.Signal{1};

            frq=obj.TMPSignal.SamplingFrequency;

            y1o=y1o.*hamming(length(y1o),'periodic');
            [f1,y1]=Plotter.MyFFT(y1o,frq);

            plot(obj.UIAxFFT,f1,y1,'-','DisplayName',char(sprintf('Microphone FFT')));

            
            idx=f1>60;
            
            [pks,locs,widths,proms] = findpeaks(y1(idx),f1(idx),'MinPeakDistance',100,'MinPeakProminence',max(y1)*0.1);
            if numel(locs)>0
                score=proms.*pks./widths;

                T=table(locs,pks,widths,proms,score,'VariableNames',{'Frequency','Amplitude','Width','Prominence','Score'});
                Tb=sortrows(T,'Score','descend');
                scatter(obj.UIAxFFT,Tb.Frequency,Tb.Amplitude,'filled','Marker','v','MarkerFaceColor','k',...
                    'DisplayName','Dominant frequency');
                text(obj.UIAxFFT,Tb.Frequency+50,Tb.Amplitude,num2str(round(Tb.Frequency,0)),...
                    'HorizontalAlignment','left');
            end

            legend(obj.UIAxFFT);
            xlim(obj.UIAxFFT,[60,6e+3]);
        end
        
        function PlotStatus(obj)
            obj.UIHammerOver.Text=sprintf('%0.3f V',obj.SigOvr(1));
            
            if obj.SigOvr(1)>3.3
                obj.UILamp.Color=[0.8500 0.3250 0.0980];
            else
                obj.UILamp.Color='white';
            end
            
        end
        
%         function 
    end
    
    methods %abstract
        function stash=Pack(obj)
            stash=struct;

        end
        
        function Populate(obj,stash)

        end
        
        function DrawGui(obj)
            g=uigridlayout(obj.Fig);
            g.RowHeight={25,25,25,25};
            g.ColumnWidth={150,75,'1x'};
            
%             lab1=uilabel(g,'Text','Hammer overflow:');
%             lab1.Layout.Row=1;
%             lab1.Layout.Column=1;
            
            lab1b=uilabel(g,'Text',' ');
            lab1b.Layout.Row=3;
            lab1b.Layout.Column=1;
            obj.UIHammerOver=lab1b;
            
%             lab2=uilabel(g,'Text','Signal overflow:');
%             lab2.Layout.Row=2;
%             lab2.Layout.Column=1;
            lab3a=uilabel(g,'Text','Roll: 0° Pitch: 0°°');
            lab3a.Layout.Row=2;
            lab3a.Layout.Column=1;
            obj.UIRollAngle=lab3a;


            
            lab2b=uilabel(g,'Text',' ');
            lab2b.Layout.Row=2;
            lab2b.Layout.Column=2;
            obj.UISensorOver=lab2b;
            
%             lab3=uilabel(g,'Text','Microphone overflow:');
%             lab3.Layout.Row=3;
%             lab3.Layout.Column=1;
            
            lamp= uilamp(g);
            lamp.Layout.Row=3;
            lamp.Layout.Column=2;
            
            obj.UILamp=lamp;

            uitsw=uiswitch(g,'Items',{'Gyro Off','Gyro On'},'ItemsData',{'0','1'},'ValueChangedFcn',@obj.MLabelSwitch);
            uitsw.Value=obj.ReadGyroBool;

            uitsw.Layout.Row=1;
            uitsw.Layout.Column=[1 2];

            uib1=uibutton(g,'Text','Show Gyro','ButtonPushedFcn',@obj.MPlotGyro);
            uib1.Layout.Row=2;
            uib1.Layout.Column=2;
        end

        function MLabelSwitch(obj,src,evnt)
            obj.ReadGyroBool=src.Value;
            SetGyro(obj);
        end

        function MPlotGyro(obj,src,evnt)
            gyro=obj.Parent.Gyro;
            ard=obj.Parent.Arduino;
            PipePlotter.PlotGyro(ard.Record);
        end


        function SetGyro(obj)
            switch obj.ReadGyroBool
                case '1'
                    obj.Parent.GyroOn;
                case '0'
                    obj.Parent.GyroOff;
            end
        end
    end
    
    methods (Static)
        function [f,y]=MyFFT(Signal,freq)
            warning('off','all');
            Fs = freq;                % Sampling frequency
            T = 1/Fs;                  % Sampling period

            L=length(Signal);
            t = (0:L-1)*T;  
            Y = fft(Signal);

            P2 = abs(Y/L(1));
            P1 = P2(1:L/2+1);
            P1(2:end-1) = 2*P1(2:end-1);

            L2=length(P1);

            f=zeros(L2,1);

            f(:,1)=Fs*(0:(L/2))/L;
            y=P1;
            warning('on','all');
        end
    end
end

