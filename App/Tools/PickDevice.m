classdef PickDevice < handle
    properties
        Parent;
        UIFig;
        UITable;
        UIButtonPick;
        UIButtonCancle;
        Devlist;
        Data;
        RowDevice=0;
    end

    methods
        function obj=PickDevice(parent)
            obj.Parent=parent;
            obj.Devlist = daqlist;
        end

        function DrawGUI(obj)
            obj.UIFig=uifigure;
            g=uigridlayout(obj.UIFig);
            g.RowHeight = {25,'1x',50};
            g.ColumnWidth = {200,'1x',200};
            
            obj.Data=obj.Devlist(:,1:end-1);
            obj.Data.Selected(:)=false;
            obj.UITable=uitable(g,"Data",obj.Data,'CellSelectionCallback',@obj.MPickID);
            obj.UITable.Layout.Row=2;
            obj.UITable.Layout.Column=[1 3];

            but1=uibutton(g,'Text','Select device','ButtonPushedFcn',@obj.SetVendor);
            but1.Layout.Row=3;
            but1.Layout.Column=1;


        end

        function MPickID(obj,src,evnt)
            if ~isempty(evnt.Indices)
                obj.Data.Selected(:)=false;
                obj.RowDevice=evnt.Indices(1);
                obj.Data.Selected(obj.RowDevice)=true;
                obj.UITable.Data=obj.Data;
            end
        end

        function SetVendor(obj,src,evnt)
            if obj.RowDevice>0
                deviceID = obj.Devlist.DeviceID(obj.RowDevice);
                vendor = obj.Devlist.DeviceInfo(obj.RowDevice).Vendor.ID;
                measurementType=obj.Devlist.DeviceInfo(obj.RowDevice).Subsystems.DefaultMeasurementType;           
                d = daq(vendor);
                addinput(d, deviceID, 1, measurementType);
                SetDevice(obj.Parent,d);
                close(obj.UIFig);
            end
        end

        
    end
end