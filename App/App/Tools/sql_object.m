classdef sql_object < handle
  % Object based wrapper for mksqlite
  % For mksqlite see https://sourceforge.net/projects/mksqlite/
  % or https://github.com/AndreasMartin72/mksqlite.git

  properties (SetAccess = protected)
    dbid                  % DB identifier
  end

  properties (Access = protected, Hidden = true)
    result_type           % Result type (0=array of structs, 1=struct array or 2=cell array)
    typed_blobs           % How to store complex MATLAB data (0,1,2)
    compression_mode      % Compression method (lz4', 'lz4hc', 'blosclz', 'lin16', 'log16')
    compression_level     % Compression level 0..9 (0=off)
    param_wrapping        % Enable multiple calls for the same SQL statement (0,1)
    null_as_nan           % Return NULL values as NaN (0,1)
    compression_check     % Validate data when using compression (0,1)
    streaming             % Serializing MATLAB data (0,1)
    busytimeout           % SQL busy timeout in [ms]

    version               % mksqlite version
    lang                  % Language (0=english, 1=german)
  end

  properties (Dependent)
    ResultType            % Result type (0=array of structs, 1=struct array or 2=cell array)
    TypedBlobs            % How to store complex MATLAB data (0,1,2)
    ParamWrapping         % Enable multiple calls for the same SQL statement (0,1)
    NullAsNaN             % Return NULL values as NaN (0,1)
    CompressionCheck      % Validate data when using compression (0,1)
    Streaming             % Serializing MATLAB data (0,1)

    BusyTimeout           % SQL busy timeout in [ms]
    Lang                  % Language (0=english, 1=german)
  end



  methods (Static)
    function Status
        % Outputs the status of available database slots to the command window
        mksqlite( 'status' );
    end

    function varargout = VersionMex
        % Returns the version number of mksqlite to command window or as function result
        if nargout
            [varargout{1:nargout}] = mksqlite( 'version mex' );
        else
            mksqlite( 'version mex' );
        end
    end % VersionMex()

    function varargout = VersionSql
        % Returns the version number of SQLite(R) to command window or as function result
        if nargout
            [varargout{1:nargout}] = mksqlite( 'version sql' );
        else
            mksqlite( 'version mex' );
        end
    end % VersionSql()

    function SetLang(value)
        % Sets the locale (0=english, 1=german)
        mksqlite( 'lang', value );
    end % setLang()

    function cond = ConditionList( name, list )
      % Build a conditional list in the form 'name IN ("first", "second", ...)' if list is a cellstring
      % or 'name IN (first, second, ...)' if list is numeric
      if isnumeric( list )
        cond = sprintf( ',%d', list );
      elseif iscellstr( list )
        cond = sprintf( ',"%s"', list{:} );
      else
        assert( false );
      end
      cond = sprintf( '%s IN (%s)', name, cond(2:end) );
    end % ConditionList()
    
  end % methods(Static)



  methods
    function obj = sql_object( arg, mode )
        % Create a new instance of sql_object.
        % arg may be a filename ('' or ':memory:' creates an in-memory database)
        % or numeric to attach a database opened with mksqlite( 'open', ...) command.
        mex_ver = mksqlite( 'version mex' );
        mex_ver_dot = strfind( mex_ver, '.' );
        mex_ver_major = int16( str2double( mex_ver(1:mex_ver_dot-1) ) );
        mex_ver_minor = int16( str2double( mex_ver(mex_ver_dot+1:end) ) );
        obj.version = mex_ver_major * 1000 + mex_ver_minor;
        obj.dbid = 0;
        
        if nargin == 1 && isempty( arg ) && ~ischar( arg )
            return
        end
        
        if nargin == 1 && isnumeric( arg )
            obj.attach( arg );
        else
            arg_filename = arg;
          
            if( ~exist( 'mode', 'var' ) )
                mode = 'rwc';
            end
            
            obj.dbid = mksqlite( 0, 'open', arg_filename, mode );
            obj.SetCompression( 'blosclz', 0 );
            obj.ResultType       = 0;
            obj.TypedBlobs       = 0;
            obj.NullAsNaN        = 0;
            obj.ParamWrapping    = 0;
            obj.CompressionCheck = 1;
            obj.Streaming        = 0;
            obj.BusyTimeout      = 10000;
        end
    end % sql_object()

    function delete(obj)
        % Destructor
        % Note:
        % If you create application defined SQL functions with CreateFunction or
        % CreateAggegation, mksqlite holds persistent variables for this database.
        % Hence the behaviour of mksqlite (and sql_object) is conform to using 
        % persistent variables in MATLAB:
        % This object is not deleted (and this destructor not called) until these persistent
        % variables are released. The functions from the following list do remove them:

        % - mksqlite( dbid, 'close' )  % (Removal only for databases defined by dbid!)
        % - clear functions
        % - clear mksqlite
        % - clear all
        % - (clear classes?)
        % - Exiting MATLAB
        if obj.dbid > 0
            mksqlite( obj.dbid, 'close' );
        end
    end % delete()
    
    function result = Databases(obj)
        % Returns a list of opened databases
        result = mksqlite( obj.dbid, 'PRAGMA database_list' );
    end % Databases()
    
    function result = Tables(obj)
        % Returns a list of tables for given database
        result = mksqlite( obj.dbid, 'show tables' );
    end

    function value = Filename(obj, database)
        % Returns the filename for an opened database
        if ~exist( 'database', 'var' )
            database = 'MAIN';
        end
        value = mksqlite( obj.dbid, 'filename', database );
    end % Filename()

    function set.ResultType(obj, value)
        mksqlite( 'result_type', value );
        obj.result_type = value;
    end % setResultType()

    function value = get.ResultType(obj)
        value = obj.result_type;
    end % ResultType()

    function set.TypedBlobs(obj, value)
        mksqlite( 'typedBLOBs', value );
        obj.typed_blobs = value;
    end % setTypedBlobs()

    function value = get.TypedBlobs(obj)
        value = obj.typed_blobs;
    end % getTypedBlobs()

    function set.NullAsNaN(obj, value)
        mksqlite( 'NullAsNaN', value );
        obj.null_as_nan = value;
    end % setNullAsNaN()

    function value = get.NullAsNaN(obj)
        value = obj.null_as_nan;
    end % getNullAsNaN()

    function set.ParamWrapping(obj, value)
        mksqlite( 'param_wrapping', value );
        obj.param_wrapping = value;
    end % setParamWrapping()

    function value = get.ParamWrapping(obj)
        value = obj.param_wrapping;
    end % getParamWrapping()

    function set.CompressionCheck(obj,value)
        mksqlite( 'compression_check', value );
        obj.compression_check = value;
    end % setCompressionCheck()

    function value = get.CompressionCheck(obj)
        value = obj.compression_check;
    end % getCompressionCheck()

    function set.Streaming(obj, value)
        mksqlite( 'streaming', value );
        obj.streaming = value;
    end % setStreaming()

    function value = get.Streaming(obj)
        value = obj.streaming;
    end % getStreaming()

    function set.BusyTimeout(obj, value)
        mksqlite( obj.dbid, 'setbusytimeout', value );
        obj.busytimeout = value;
    end % setBusyTimeout()

    function value = get.BusyTimeout(obj)
        value = obj.busytimeout;
    end % getBusyTimeout()

    function SetCompression(obj, mode, level )
        % Sets the compression mode and level for typed BLOBs
        if isempty(mode) && level == 0
            mode = 'blosclz';
        end
        mksqlite( 'compression', mode, level );
        obj.compression_mode = mode;
        obj.compression_level = level;
    end % SetCompression()

    function [mode, level] = GetCompression(obj)
        % Gets the compression mode and level for typed BLOBs
        mode = obj.compression_mode;
        level = obj.compession_level;
    end % getCompression()

    function CreateFunction( obj, varargin )
        % Creates an application defined SQL function
        mksqlite( obj.dbid, 'create function', varargin{:} );
    end % CreateFunction()

    function CreateAggregation( obj, varargin )
        % Creates an application defined aggregation function
        mksqlite( obj.dbid, 'create aggregation', varargin{:} );
    end % CreateFunction()

    function varargout = Select( obj, query, varargin )
        % SQL SELECT statement ( obj.Select( '* FROM tbl' ) )
        assert( ischar(query), 'Query must be string type!' );
        obj.prepare_stmt();

        query = sprintf( 'SELECT %s', query );
        if ~nargout
            mksqlite( obj.dbid, query, varargin{:} );
        else
            [varargout{1:nargout}] = mksqlite( obj.dbid, query, varargin{:} );
        end
    end % Select()

    function varargout = SelectEx( obj, query, varargin )
        % SQL SELECT statement with expression builder ( obj.SelectEx( '%s FRO tbl', 'name' ) )
        assert( ischar(query), 'Query must be string type!' );
        
        query = sprintf( 'SELECT %s', query );
        
        if ~nargout
            obj.exec( query, varargin{:} );
        else
            [varargout{1:nargout}] = obj.exec( query, varargin{:} );
        end
    end
    
    function Attach( obj, alias, filename )
        % Attach another opened database to this database
        mksqlite( obj.dbid, sprintf( 'ATTACH ? AS "%s"', alias ), filename );
    end % Attach()

    function Detach( obj, alias )
        % Detach an attached database
        mksqlite( obj.dbid, sprintf( 'DETACH %s', alias ) );
    end % Detach()

    function Begin(obj)
        % SQL BEGIN statement
        mksqlite( obj.dbid, 'BEGIN' );
    end

    function Commit(obj)
        % SQL COMMIT statement
        mksqlite( obj.dbid, 'COMMIT' );
    end

    function Rollback(obj)
        % SQL ROLLBACK statement
        mksqlite( obj.dbid, 'ROLLBACK' );
    end

    function varargout = exec_raw( obj, query, varargin )
        % Execute SQL statement
        obj.prepare_stmt();

        if ~nargout
            mksqlite( obj.dbid, query, varargin{:} );
        else
            [varargout{1:nargout}] = mksqlite( obj.dbid, query, varargin{:} );
        end
    end % exec_raw()

    function varargout = exec( obj, query, varargin )
        % Execute SQL statement with expression builder
        obj.prepare_stmt()

        % count sprintf placeholders (i.e. %d)
        % nParams holds the number of placeholders
        i = 1;
        nParams = 0;
        while i < length(query)
            if query(i) == '%'
                nParams = nParams + 1;
                % check for '%%', which is no sprintf placeholder
                if query(i+1) == '%'
                    query(i+1) = [];
                    nParams = nParams - 1;
                end
            end
            i = i + 1;
        end

        % if there are placeholders in SQL string, build
        % the SQL query by sprintf() first.
        % First nParams parameters are taken as sprintf parameter list.
        if nParams > 0
            query = sprintf( query, varargin{1:nParams} );
            varargin(1:nParams) = []; % remove sprintf parameters
        end

        args = [ obj.dbid, {query}, varargin ];

        % kv69 support named binding (only non-extended typedBLOBs)
        if isstruct(args{end}) && obj.typed_blobs < 2
            % Replace special tokens [#], [:#], [=#], [+#] and [-#] referencing struct argument
            [match, tokens] = regexp( query, '\[(.?)#\]', 'match', 'tokens' );
            for i = 1:numel( match )
                query = strrep( query, match{i}, obj.field_list( args{end}, tokens{i}{1} ) );
            end

            args = [ obj.dbid, {query}, varargin ];

            % Get bind names starting with ":" as cell array. (Colon is not part of the names taken)
            binds = regexp( query, ':(\w*)', 'tokens' );
            binds = [binds{:}]; % resolve nested cells
            if isempty( binds )
                % No named bind names, discard struct argument!
                args(end) = [];
            else
                % Since version 2.1 mksqlite handles named bindings with a struct
                % argument. For versions prior a cell argument have to be built for
                % compatibility reasons:
                if obj.version <= 2001
                    [~, idx, ~] = unique(binds, 'first'); % Get the indexes of all elements excluding duplicates
                    binds = binds( sort(idx) ); % get unique elements, preserving order
                    dataset = rmfield( args{end}, setdiff( fieldnames(args{end}), binds ) ); % remove unused fields
                    dataset = orderfields( dataset, binds ); % order remaining fields to match occurence in sql statement
                    dataset = struct2cell( dataset(:) ); % retrieve data from structure (column-wise datasets)
                    args = [args(1:end-1), dataset(:)'];
                end
            end
        end

        % remaining arguments are for SQL parameter binding
        if ~nargout
            mksqlite( args{:} );
        else
            [varargout{1:nargout}] = mksqlite( args{:} );
        end

      end % exec()
  end % methods

  methods (Hidden = true, Access = protected)
    function attach(obj, dbid)
        % Attach database dbid with current settings
        assert( dbid > 0 && dbid ~= obj.dbid );
        
        mksqlite( dbid, 'SELECT 0' ); % Ensure dbid is valid
        
        if obj.dbid > 0
          mksqlite( obj.dbid, 'close' );
        end
        obj.dbid = dbid;

        value = mksqlite( 'result_type', 0 );
        obj.ResultType = value;
        value = mksqlite( 'typedBLOBs', 0 );
        obj.TypedBlobs = value;
        value = mksqlite( 'param_wrapping', 0 );
        obj.ParamWrapping = value;
        value = mksqlite( 'compression', 'blosclz', 0 );
        obj.SetCompression( value{1}, value{2} );
        value = mksqlite( 'NullAsNaN', 0 );
        obj.NullAsNaN = value;
        value = mksqlite( 'compression_check', 0 );
        obj.CompressionCheck = value;
        value = mksqlite( 'streaming', 0 );
        obj.Streaming = value;
        value = mksqlite( obj.dbid, 'setbusytimeout', 10000 );
        obj.BusyTimeout = value;
    end
      
    function prepare_stmt(obj)
        % Preset mksqlite options
        mksqlite( 'result_type', obj.result_type );
        mksqlite( 'typedBLOBs', obj.typed_blobs );
        mksqlite( 'param_wrapping', obj.param_wrapping );
        mksqlite( 'compression', obj.compression_mode, obj.compression_level );
        mksqlite( 'NullAsNaN', obj.null_as_nan );
        mksqlite( 'compression_check', obj.compression_check );
        mksqlite( 'streaming', obj.streaming );
    end % prepare_stmt()

    function list = field_list( obj, struct_var, mode )
        % Create a comma separated list of fields depending on "mode" for the expression builder
        assert( isstruct( struct_var ), '<struct_var must> be a structure type variable' );

        if ~exist( 'mode', 'var' )
            mode = '';
        else
            assert( ischar( mode ) && numel( mode ) < 2, '<mode> must be a char type variable' );
        end

        fnames = fieldnames( struct_var );
        switch mode
            case ''
                % Comma separated field names
                list = sprintf( '%s,', fnames{:} );
            case ':'
                % Comma separated field names, preceded by a colon
                % Example: sql( 'INSERT INTO tbl ([#]) VALUES ([:#]) WHERE ...', struct( 'a', 3.14, 'b', 'String', 'd', 1:5 ) )
                list = sprintf( ':%s,', fnames{:} );
            case '='
                % Comma separated list of assignments
                % Example: sql( 'UPDATE tbl SET [=#] WHERE ...', struct( 'a', 3.14, 'b', 'String', 'd', 1:5 ) )
                fnames = [fnames(:),fnames(:)]';
                list = sprintf( '%s=:%s,', fnames{:} );
            case '+'
                % 'AND' joined list of comparisations for SQL WHERE statement i.e.
                % Example: sql( 'SELECT ... WHERE [+#]', struct( 'a', 3.14, 'b', 'String' ) )
                fnames = [fnames(:),fnames(:)]';
                list = sprintf( '%s=:%s AND ', fnames{:} );
                list(end-3:end) = []; % Remaining character deleted later
            case '*'
                % For SQL CREATE statement
                % Example: sql( 'CREATE TABLE tbl ([*#])', struct( 'a', 'REAL', 'b', 'TEXT', 'ID', 'INTEGER PRIMARY KEY' ) )
                defs = struct2cell( struct_var );
                defs = [fnames(:),defs(:)]';
                list = sprintf( '%s %s,', defs{:} );
            otherwise
                error( 'MKSQLITE:SQL:UNKMODE', 'Unknown parameter <mode>' );
        end
        list(end) = [];
    end % list()
  end % methods

end % classdef

