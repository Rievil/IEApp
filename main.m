as=Asker();
as.StartReading;

%%

ST=as.SignalsTable;
DT=as.Marker.DescTable;

%%

NT=innerjoin(ST,DT,'Keys','ID');

