classdef Gyro < Module
    %GYRO Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        WinLen=2;
    end
    
    methods
        function obj = Gyro(parent)
            obj@Module(parent);
        end

        function [pitch,roll]=GetRoll(obj,ard,id)
            gdata=ard.Record;
            row=find(gdata.ID==id);
            if sum(row)==0
                row=size(gdata,1)-obj.WinLen/2;
            end

            if row>ceil(obj.WinLen/2)
                lr=row-obj.WinLen/2;
            else
                lr=1;
            end

            if row+ceil(obj.WinLen/2)<(size(gdata,1))
                rr=row+ceil(obj.WinLen/2);
            else
                rr=size(gdata,1);
            end

            Ti=gdata(lr:rr,:);
            
            Tic=PipePlotter.ClearGyro(Ti);
            [pitch,roll]=PipePlotter.GetAngle(Tic);
            pitch=mean(pitch,'all');
            roll=mean(roll,'all');
        end
    end

    methods %abstract
        function Pack(obj)
        end

        function Populate(obj)
        end

        function DrawGui(obj)
        end
    end

    methods (Static)
        function [TF2]=ClearGyro(data)
            TF2=data;
            for j=4:10
                TF2{:,j}=smoothdata(TF2{:,j},'gaussian',10);
            end
            
            TF2.GyX(TF2.GyX< 0.06 & TF2.GyX>-0.06)=0;
            TF2.GyY(TF2.GyY< 0.06 & TF2.GyY>-0.06)=0;
            TF2.GyZ(TF2.GyZ< 0.06 & TF2.GyZ>-0.06)=0;
            
            TF2.AcZ=TF2.AcZ/16384*9.81;
            TF2.AcX=TF2.AcX/16384*9.81;
            TF2.AcY=TF2.AcY/16384*9.81;
            
            sen=(16.4/2);
            TF2.GyX=TF2.GyX/(32750)*sen;
            
            TF2.GyY=TF2.GyY/(32750)*sen;
            
            TF2.GyZ=TF2.GyZ/(32750)*sen;
            
            [pitch,roll]=GetAngle(TF2);
            TF2=[TF2, table(pitch,roll,'VariableNames',{'pitch','roll'})];
        end

        function [pitch,roll]=GetAngle(gyrodata)

            TA=gyrodata;
        
            x=TA.AcX;
            y=TA.AcY;
            z=TA.AcZ;
            
            pitch=zeros(numel(x),1);
            roll=zeros(numel(x),1);
            for i=1:numel(x)
                if x(i)>0 && z(i)>0
                    roll(i,1)=atan(x(i)/z(i))*57.2957795;
                elseif x(i)<0 && z(i)>0
                    roll(i,1)=atan(x(i)/z(i))*57.2957795+360;
                elseif x(i)<0 && z(i)<0
                    roll(i,1)=atan(x(i)/z(i))*57.2957795+180;
                elseif x(i)>0 && z(i)<0
                    roll(i,1)=atan(x(i)/z(i))*57.2957795+180;
                end
            end
            pitch=asin(y./9.81)*57.2957795;
        end

        function anglearr=GetCoorFromEggShape(height)
            a=height; %výška vejce
            xii=linspace(0,a,2000);
            yii=zeros(numel(xii),1);
            for i=1:numel(xii)
                yii(i,1)=power(power(a,0.5)*xii(i)-power(xii(i),1.5),1/2);
            end
            
            xif=[xii'; flip(xii')];
            yif=[yii; flip(yii.*(-1))];
            
            %otočení dle orientace v terénu
            theta=-90;
            R=[cosd(theta) -sind(theta); sind(theta) cosd(theta)];
            coordT=[xif, yif];
            rotcoord=coordT*R';
            
            t=rotcoord(:,1);
            y=rotcoord(:,2);
            
            [M,I]=max(t);
            y=y-y(I);
            
            % plot(t,y);
            
            anglearr=zeros(numel(y),3);
            for i=1:numel(y)-1
                dy=diff(y)./diff(t);
                k=i; % point number 220
                tang=(t-t(k))*dy(k)+y(k);
            %     hold on
                if k<51 || k>numel(t)-51
                    red=k-1;
                else
                    red=50;
                end
                
                xd=max(t)-min(t);
                yd=max(tang)-min(tang);
                ang=atan(yd/xd)*57.2957795;
                if t(k)>0 && y(k)>0
                    ang=ang+180;
                elseif t(k)>0 && y(k)<0
                    ang=360-ang;
                elseif t(k)<0 && y(k)<0
                    ang=ang;
                elseif t(k)<0 && y(k)>0
                    ang=ang+90;
                elseif t(k)==0 && y(k)>0
                    ang=180;
                elseif t(k)==0 && y(k)<0
                    ang=0;
                else
                    ang=0;
                end
                anglearr(i,1)=ang;
                anglearr(i,2)=t(i);
                anglearr(i,3)=y(i);
            end
        end

        function Fig=PlotGyro(data)
            TF2=data;
            %
            [TF2]=ClearGyro(data);
            %
            
            Fig=figure;
            
            xo=TF2.Time;
            x=second(TF2.Time);
            x=x-x(1);
            freq=1/((x(end)-x(1))/numel(x));

            t=tiledlayout(2,1,"TileSpacing","compact",'Padding','tight');
            ax1=nexttile;
            hold on;
            y1=smoothdata(TF2.AcX,'gaussian',20);
            y2=smoothdata(TF2.AcY,'gaussian',20);
            y3=smoothdata(TF2.AcZ,'gaussian',20);
            
            plot(xo,TF2.AcX,'-','DisplayName','Acx');
            plot(xo,TF2.AcY,'-','DisplayName','AcY');
            plot(xo,TF2.AcZ,'-','DisplayName','AcZ');
            scatter(xo(logical(TF2.B)),TF2.AcZ(logical(TF2.B)),'Filled','DisplayName','Meas');

%             lgd=legend('location','north');
%             lgd.NumColumns=4;
            ylabel('Acceleration [m/s^{2}]');
            ax2=nexttile;
            hold on;
            
            yi1=smoothdata(TF2.GyX,'gaussian',20);
            yi2=smoothdata(TF2.GyY,'gaussian',20);
            yi3=smoothdata(TF2.GyZ,'gaussian',20);
            
            plot(xo,TF2.GyX,'DisplayName','X');
            plot(xo,TF2.GyY,'DisplayName','Y');
            plot(xo,TF2.GyZ,'DisplayName','Z');
            scatter(xo(logical(TF2.B)),TF2.GyZ(logical(TF2.B)),'Filled','DisplayName','Meas');
            lgd=legend;
            lgd.NumColumns=4;
            lgd.Layout.Tile = 'South';
            ylabel('Angle velocity [°/s]');
            xlabel(t,'Time');
        end

        function [fig,ax1]=PlotPipe(TFG2,TA)
            fig=figure('position',[0 80 750 750]);
            t=tiledlayout('flow','TileSpacing','tight','Padding','tight');
            nexttile;
            hold on;
            box on;
            grid on;
            ax1=gca;
            
            unqdepth=unique(TFG2.Depth);
            yvallabel='GuessClass';
            go=[];
            xa=[];
            ya=[];
            za=[];
            fr=[];
            for ln=1:numel(unqdepth)
                Tia=linspace(unqdepth(ln),unqdepth(ln),size(TA,1))';
                Tib=linspace(unqdepth(ln),unqdepth(ln),size(TFG2,1))';
                
                Idxi=TFG2.Depth==unqdepth(ln);
                if ln==1
                    go(end+1)=scatter3(ax1,TFG2.X(Idxi),Tib(Idxi),TFG2.Y(Idxi),200,TFG2.(yvallabel)(Idxi),'filled','DisplayName','Měření pomocí IEDevice');
                    go(end+1)=plot3(ax1,TA.X,Tia,TA.Y,'-','Color',[0.5 0.5 0.5 0.5],'DisplayName','Počítaný obvod trouby');
                else
                    scatter3(ax1,TFG2.X(Idxi),Tib(Idxi),TFG2.Y(Idxi),200,TFG2.(yvallabel)(Idxi),'filled','DisplayName','Měření pomocí IEDevice');
                    plot3(ax1,TA.X,Tia,TA.Y,'-','Color',[0.5 0.5 0.5 0.5],'DisplayName','Počítaný obvod trouby');
                end
                xa=[xa; TFG2.X(Idxi)];
                ya=[ya; Tib(Idxi)];
                za=[za; TFG2.Y(Idxi)];
                fr=[fr; TFG2.(yvallabel)(Idxi)];
            
            
            
            end
            colormap(ax1,"jet");
            cbar=colorbar;
            cbar.Label.String=yvallabel;
            % set( cbar, 'YDir', 'reverse' );
            caxis(ax1,[min(TFG2.(yvallabel))*0.8,max(TFG2.(yvallabel))*1.2]);
            xlabel(ax1,'Šířka [m]');
            zlabel(ax1,'Výška [m]');
            ylabel(ax1,'Hloubka [m]');
            legend(ax1,go,'location','southoutside');
            view(ax1,60,45);
            
            
            ax2=axes(fig,'position',[0.15 0.85 0.2 .12]);
            hi=histogram(ax2,TFG2.(yvallabel));
            set(ax2,'Color','none','box','off');
            xlabel(ax2,yvallabel);
            ylabel(ax2,'Počet [-]');
            xt=hi.BinEdges(2:end)-hi.BinWidth/2;
            yt=hi.BinCounts;
            text(ax2,xt',yt'+0.07*max(yt),num2str(yt'),'HorizontalAlignment','Center',...
                'FontSize',8);
        end
    end
end

