classdef StockfishParser < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        %UCI object for all commands to and from stockfish
        uci;
        
        %ChessBoard
        ChessBoard;
        
        %Turn, 0 for white 1 for black
        turn = 1;
        
    end
    
    methods
        
        function obj = StockfishParser(ChessBoard)
            obj.UCIFields();
            obj.ChessBoard = ChessBoard;
        end
        
        function args = ParseArgs(obj, str,fields)
            % Extract key-value pairs from input string
            pat = sprintf('(\\<%s\\>)|',fields{:});
            [keys, vals] = regexp(str,pat,'match','split');
            
            % Return key-value pairs as strucutre fields
            args = struct();
            for i = 1:length(keys)
                % Trim value string
                val = strtrim(vals{i + 1});
                
                % Check if key already exists
                if isfield(args,keys{i})
                    % Append value to key's cell
                    if ~iscell(args.(keys{i}))
                        args.(keys{i}) = {args.(keys{i})};
                    end
                    args.(keys{i}){end + 1} = val;
                else
                    % Save value as new key
                    args.(keys{i}) = val;
                end
            end
        end
        
        
        
        function str = ConstructArgs(obj, args, fields)
            % Loop over input fields
            str = '';
            for i = 1:length(fields)
                % Check if argument is valid
                if isfield(args,fields{i})
                    % Append field args to str
                    switch class(args.(fields{i}))
                        case 'double'
                            str = sprintf('%s %s %.0f ',str,fields{i}, ...
                                args.(fields{i}));
                        case 'char'
                            str = sprintf('%s %s %s ',str,fields{i}, ...
                                args.(fields{i}));
                        case 'logical'
                            if (args.(fields{i}) == true)
                                str = sprintf('%s %s ',str,fields{i});
                            end
                        case 'cell'
                            str = sprintf('%s ',str,fields{i}, ...
                                args.(fields{i}){:});
                    end
                    str = strtrim(str);
                end
            end
        end
        
        %Generates UCI field lists for Stockfish
        %Split into GUI and Engine fields, GUI being user and Engine being
        %Stockfish
        function UCIFields(obj)
            % GUI commands
            obj.uci.gui.cmds = {'uci','debug','isready','setoption', ...
                'register','ucinewgame','position', ...
                'go','stop','ponderhit','quit'};
            obj.uci.gui.debug = {'on','off'};
            obj.uci.gui.setoption = {'name','value'};
            obj.uci.gui.register = {'later','name','code'};
            obj.uci.gui.position = {'startpos','fen','moves'};
            obj.uci.gui.go = {'ponder','searchmoves','wtime','btime', ...
                'winc','binc','movestogo','depth','nodes', ...
                'mate','movetime','infinite'};
            
            % Engine commands
            obj.uci.engine.cmds = {'id','uciok','readyok','bestmove', ...
                'copyprotection','registration','info','option'};
            obj.uci.engine.id = {'name','author'};
            obj.uci.engine.bestmove = {'ponder'};
            obj.uci.engine.copyprotection = {'checking','ok','error'};
            obj.uci.engine.registration = {'checking','ok','error'};
            obj.uci.engine.info = {'depth','seldepth','time','nodes','pv', ...
                'multipv','score','currmove', ...
                'currmovenumber','hashfull','nps', ...
                'tbhits','sbhits','cpuload','string', ...
                'refutation','currline'};
            obj.uci.engine.score = {'cp','mate','lowerbound','upperbound'};
            obj.uci.engine.option = {'name','type','default', ...
                'min','max','var'};
        end
        
        function fen = FENParser(obj, str)
            fen = '';
                        
            for i = 8:-1:1
                for j = 1:8
                    storeAt = (j-1)*8+i;
                    if obj.ChessBoard.ChessBoardCellArray(storeAt).CurrentPiece == 1
                        if obj.ChessBoard.ChessBoardCellArray(storeAt).ColorOfPiece == 'w'
                            fen = strcat(fen, 'P');
                        else
                            fen = strcat(fen, 'p');
                        end
                    elseif obj.ChessBoard.ChessBoardCellArray(storeAt).CurrentPiece == 4 %Rook
                        if obj.ChessBoard.ChessBoardCellArray(storeAt).ColorOfPiece == 'w'
                            fen = strcat(fen, 'R');
                        else
                            fen = strcat(fen, 'r');
                        end
                    elseif obj.ChessBoard.ChessBoardCellArray(storeAt).CurrentPiece == 2 %Knight
                        if obj.ChessBoard.ChessBoardCellArray(storeAt).ColorOfPiece == 'w'
                            fen = strcat(fen, 'N');
                        else
                            fen = strcat(fen, 'n');
                        end
                    elseif obj.ChessBoard.ChessBoardCellArray(storeAt).CurrentPiece == 3 %Bishop
                        if obj.ChessBoard.ChessBoardCellArray(storeAt).ColorOfPiece == 'w'
                            fen = strcat(fen, 'B');
                        else
                            fen = strcat(fen, 'b');
                        end
                    elseif obj.ChessBoard.ChessBoardCellArray(storeAt).CurrentPiece == 5 %Queen
                        if obj.ChessBoard.ChessBoardCellArray(storeAt).ColorOfPiece == 'w'
                            fen = strcat(fen, 'Q');
                        else
                            fen = strcat(fen, 'q');
                        end
                    elseif obj.ChessBoard.ChessBoardCellArray(storeAt).CurrentPiece == 6 %King
                        if obj.ChessBoard.ChessBoardCellArray(storeAt).ColorOfPiece == 'w'
                            fen = strcat(fen, 'K');
                        else
                            fen = strcat(fen, 'k');
                        end
                    else %Empty square
                        fen = strcat(fen, '1');
                    end
                    
                end
                fen = strcat(fen, '/');
            end
            fen = fen(1:end-1);
            %Is it white or black moving
            
            if str == 'w'
                fen = strcat(fen, ' w');
            else
                fen = strcat(fen, ' b');
                obj.turn = obj.turn + 1;
            end
            
            %CHECK IF KING CASLTING IS POSSIBLE
            fen = strcat(fen, ' KQkq');
            
            %En passant rules, keep for now
            fen = strcat(fen, ' -');
            
            %Halfmove clock, keep at 0
            fen = strcat(fen, ' 0');
            
            %Turn order, icnrement after black move
            fen = strcat(fen, [' ', num2str(obj.turn)]);
        end
        
        function str = ConvertToString(obj, startPos, endPos)
            startX = startPos(1);
            startY = char(startPos(2)+96);
            startPosition = strcat(startY, num2str(startX));    
            endX = endPos(1);
            endY = char(endPos(2)+96);
            endPosition = strcat(endY, num2str(endX));
            str = strcat(startPosition, endPosition);
        end
        
        function [startPos, endPos] = ConvertToNumber(obj, str)            
            startX = str2num(str(2));
            startY = -(96-str(1));
            startPos = [startX, startY];
            endX = str2num(str(4));
            endY = -(96 - str(3));
            endPos = [endX, endY];
        end
    end
end

