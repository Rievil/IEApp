clear all
close all
clc
dummy = mksqlite('version mex');
fprintf( '\n\n' );

assert( exist( 'sql_object', 'class' ) == 8, ...
      ['You need sql_object from ', ...
       'https://de.mathworks.com/matlabcentral/fileexchange/58433-using-sqlite-databases-via-objects ', ...
       'to run this test!'] );

%%
db = sql_object( 'my_test.db' );
db.ParamWrapping = 1;
% db.exec( 'CREATE TABLE tbl (id INT PRIMARY KEY, name TEXT)' );

%%
db.Begin;
db.exec( 'SELECT * FROM  test_table;');
db.Commit;

%%
clear db;