classdef Stockfish < handle
    
    properties
        %directory where everything is located.
        dir;
        
        %data which contains engine information, paths etc...
        data;
        
        engineList; %List of supported engines
        engineBook; %Path to opening book
        engineIdx; %Current engine index (stockfish is only one)
        enginePath; %Path to the stockfish executable
        
        %Max CPU
        MAX_CPU = 1;
        
        %Communication variables
        process; %Engine process
        inputStream; %GUI input stream (What engine prints)
        outputStream; %GUI output stream (What user prints)
        timerobj; %Asynchronous communication timer
        
        %Stockfish Parser
        stockfishParser;
        
        %Chess engine name
        name;
        
        %Chess engine author
        author;
        
        %Chess option list
        options;
        
        %FEN String (Stockfish notation)
        fen;
        
        %log file ID
        fileID;
        
        %debug
        args;
        
        %best move available
        bestmove;
        
        %Chessboard
        ChessBoard;
    end
    
    methods
        
        function obj = Stockfish(ChessBoard)
            obj.ChessBoard = ChessBoard;
            obj.SetDirectory();
            obj.SetEngineProperties();
            obj.stockfishParser = StockfishParser(ChessBoard);
            
            obj.fileID = fopen('log.txt','w');
            
            obj.OpenLink();
            
            obj.SendCommand('uci');
            obj.ReadUntilCMD('uciok');
            
            obj.ReadyHandshake();
            
            obj.SetOption('Ponder', 'false');
            obj.SetOption('Minimum Thinking Time', '0');
            
            %obj.SetOption('OwnBook','false');
            
            obj.SendCommand('ucinewgame');
            
            
%             obj.GetBestMove();
%             
%             obj.UpdatePosition();
%             obj.SendCommand('d');
%             
%             obj.GetBestMove();
%             
%             obj.CloseLink();          
        end

        %Sets directory in which everything is located
        function SetDirectory(obj)
            %Change to desired directory
            stockfishDir = 'C:\Users\Max\AppData\Roaming\MathWorks\MATLAB Add-Ons\Collections\Chess Master\Chess Master v1.6';
            
            %Change the "\"to "/
            obj.dir = regexprep(stockfishDir,'\','/');
        end
        
        %Sets up the engine properties for available engine
        function SetEngineProperties(obj)
            obj.data = load([obj.dir '/data.mat']);
            
            engines = obj.data.engines;
            obj.engineList = engines.list;
            obj.engineBook = engines.book;
            obj.engineIdx = engines.idx;
            stockfishPath = obj.engineList(obj.engineIdx).path;
            
            %set the path as the absolute path to executable
            obj.enginePath = regexprep(stockfishPath,'\','/');
            
            % Replace beginning ./ with base directoy
            if ((length(obj.enginePath) >= 2) && strcmp(obj.enginePath(1:2),'./'))
                obj.enginePath = [obj.dir obj.enginePath(2:end)];
            end
        end
        
        function SetOption(obj,name,value)
            try
                % Find name in options list
                inds = cellfun(@(s)strcmpi(s.name,name),obj.options);
                idx = find(inds);
                assert(~isempty(idx));
                
                % Send command to engine
                arguments = struct('name',name,'value',value);
                obj.SendCommand('setoption',arguments);
                
                % Update options value
                obj.options{idx}.default = value;
            catch
                % Write warning line to engine log
                fprintf(obj.fileID, '\n');
                fprintf(obj.fileID, 'Failed to set %s to %s',name,value);
                fprintf(obj.fileID, '\n');
            end
        end
        
        %Opens link by setting permissions before opening the input and
        %output streams
        function OpenLink(obj)
            %Try to set execute permissions
            if (ispc == true)
                % Windows
                usr = 'Everyone';
                cmd = sprintf('icacls "%s" /grant %s:RX',obj.enginePath,usr);
                [~,~] = system(cmd);
            end
            
            %Spawn engine process
            obj.process = java.lang.ProcessBuilder(obj.enginePath).start();
            
            %Connect to engine Stdout
            iStream = obj.process.getInputStream();
            iStreamReader = java.io.InputStreamReader(iStream);
            obj.inputStream = java.io.BufferedReader(iStreamReader);
            
            % Connect to engine's stdin
            oStream = obj.process.getOutputStream();
            obj.outputStream = java.io.PrintWriter(oStream,true);
            
            % Initialize asynchronous communication timer
            obj.timerobj = timer('Name','EngineInterfaceTimer', 'ExecutionMode','FixedRate');
        end
        
        %Closes link by quitting Stockfish and destroying communication
        %process
        function CloseLink(obj)
            obj.SendCommand('quit');
            
            obj.process.destroy();
            
            fclose(obj.fileID);
        end
        
        %Update the board FEN string and send it to chess engine with best
        %move determined
        function UpdatePosition(obj, turn)
            argument.fen = obj.stockfishParser.FENParser(turn);
            obj.fen = argument.fen; %debug
            obj.SendCommand('position', argument);
        end
        
        function UpdateMove(obj, turn)
            argument.fen = obj.stockfishParser.FENParser(turn);
            obj.fen = argument.fen; %debug
            argument.moves = obj.bestmove.move;
            obj.SendCommand('position', argument);
        end
        
        %Gets the best move from the chess engine
        function GetBestMove(obj)
            argument.movetime = 10;
            obj.SendCommand('go', argument);
            obj.bestmove = obj.ReadUntilCMD('bestmove');
        end
    
        
        %Takes the command and the arguments of the command as inputs
        function SendCommand(obj, cmd, args)
            switch cmd
                case 'debug'
                    % Construct debug command
                    fields = obj.stockfishParser.uci.gui.debug;
                    str = obj.stockfishParser.ConstructArgs(args,fields);
                case 'setoption'
                    % Construct setoption command
                    fields = obj.stockfishParser.uci.gui.setoption;
                    str = obj.stockfishParser.ConstructArgs(args,fields);
                case 'register'
                    % Construct register command
                    fields = obj.stockfishParser.uci.gui.register;
                    str = obj.stockfishParser.ConstructArgs(args,fields);
                case 'position'
                    % Construct position command
                    fields = obj.stockfishParser.uci.gui.position;
                    str = obj.stockfishParser.ConstructArgs(args,fields);
                case 'go'
                    % Construct go command
                    fields = obj.stockfishParser.uci.gui.go;
                    str = obj.stockfishParser.ConstructArgs(args,fields);
                otherwise
                    % No additional arguments
                    str = '';
            end
            
            % Construct line string
            line = strtrim(sprintf('%s %s',cmd,str));
            
            % Send line, if non-empty
            if ~isempty(line)
                % Send line to engine
                obj.SendLine(line);
            end
            
        end
        
        function SendLine(obj, line)
            %Send line to output stream
            obj.outputStream.println(line);
            fprintf(obj.fileID, '\n');
            fprintf(obj.fileID, line);
            fprintf(obj.fileID, '\n');
        end
        
        function [isReady, line] = GetLine(obj)
            %             isReady = obj.inputStream.ready();
            %             if(isReady == true)
            %                 line = char(obj.inputStream.readLine());
            %             else
            %                 line = '';
            %             end
            isReady = true;
            line = char(obj.inputStream.readLine());
            fprintf(obj.fileID, line);
            fprintf(obj.fileID, '\n');
        end
        
        function ReadyHandshake(obj)
            % Ask the engine if it's ready to go
            obj.SendCommand('isready');
            
            % Wait for engine to respond with 'readyok'
            obj.ReadUntilCMD('readyok');
        end
        
        
        function args = ReadUntilCMD(obj,tcmd)
            maxTime = 0.5;
            ptime = 0.5;
            nMax = maxTime / ptime;
            
            % Read until target command is received
            cmd = '';
            temp = '';
            ntries = 0;
            while (~strcmpi(temp,tcmd) && (ntries <= nMax))
                % Get command from engine
                [isReady, cmd, args] = obj.GetCommand();
                temp = strsplit(cmd);
                temp = temp(1);
                
                % Check if the engine sent anything
                if (isReady == false)
                    % Wait for engine to become responsive
                    drawnow; pause(ptime);
                    ntries = ntries + 1;
                else
                    % Reset counter
                    ntries = 0;
                end
            end
        end
        
        function [isReady, cmd, args] = GetCommand(obj)
            % Get line from engine
            [isReady, line] = obj.GetLine();
            
            % Extract command
            fields = obj.stockfishParser.uci.engine.cmds;
            pat = sprintf('(\\<%s\\>)|',fields{:});
            [cmd, str] = regexp(line,pat,'match','split','once');
            args = struct();
            if isempty(cmd)
                % Quick return
                return;
            end
            
            % Parse arguments
            str = strtrim(str{2});
            switch cmd
                case 'id'
                    % Parse id command
                    fields = obj.stockfishParser.uci.engine.id;
                    args = obj.stockfishParser.ParseArgs(str,fields);
                    
                    % Store engine name
                    if isfield(args,'name')
                        obj.name = args.name;
                    end
                    
                    % Store engine author
                    if isfield(args,'author')
                        obj.author = args.author;
                    end
                case 'bestmove'
                    % Parse bestmove command
                    strs = regexp(str,'\s+','split','once');
                    
                    % Parse (optional) ponder argument
                    if (length(strs) > 1)
                        fields = obj.stockfishParser.uci.engine.bestmove;
                        args = obj.stockfishParser.ParseArgs(strs{2},fields);
                    end
                    
                    % Save best move string
                    args.move = strs{1};
                case 'copyprotection'
                    % Parse copyprotection command
                    fields = obj.stockfishParser.uci.engine.copyprotection;
                    args = obj.stockfishParser.ParseArgs(str,fields);
                    
                    % Handle copyprotection error
                    if isfield(args,'error')
                        % Throw error
                        msgid = 'EI:COPYPROTECT:FAIL';
                        errmsg = 'Engine copyprotection failed';
                        obj.Error(msgid,errmsg);
                    end
                    %                 case 'registration'
                    %                     % Parse registration command
                    %                     fields = obj.stockfishParser.uci.engine.registration;
                    %                     args = obj.stockfishParser.ParseArgs(str,fields);
                    %
                    %                     % Handle registration error command
                    %                     if isfield(args,'error')
                    %                         % Try to register the engine
                    %                         obj.RegisterEngine();
                    %                     end
                    %                 case 'info'
                    %                     % Parse info command
                    %                     fields = obj.stockfishParser.uci.engine.info;
                    %                     args = obj.stockfishParser.ParseArgs(str,fields);
                    %
                    %                     % Parse score argument
                    %                     if isfield(args,'score')
                    %                         str = args.score;
                    %                         fields = obj.stockfishParser.uci.engine.score;
                    %                         args.score = obj.stockfishParser.ParseArgs(str,fields);
                    %                     end
                    %
                    %                     % Parse principal variation argument
                    %                     if isfield(args,'pv')
                    %                         args.pv = regexp(args.pv,'\s+','split');
                    %                     end
                    %
                    %                     % Parse refuatation argument
                    %                     if isfield(args,'refutation')
                    %                         str = args.refutation;
                    %                         args.refutation = regexp(str,'\s+','split');
                    %                     end
                    %
                    %                     % Parse current line argument
                    %                     if isfield(args,'currline')
                    %                         str = args.currline;
                    %                         args.currline = regexp(str,'\s+','split');
                    %                     end
                    %
                    %                     % Save new info
                    %                     obj.SaveInfo(args);
                case 'option'
                    % Parse option command
                    fields = obj.stockfishParser.uci.engine.option;
                    args = obj.stockfishParser.ParseArgs(str,fields);
                    
                    % Save to options list
                    obj.options{end + 1} = args;
            end
        end
        
        function Error(obj,msgid,errmsg)
            % Destroy the session
            delete(obj);
            
            % Relay error to command window
            error(msgid,errmsg);
        end
        
    end
end

