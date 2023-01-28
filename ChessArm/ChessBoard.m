classdef ChessBoard < handle
    properties
        ChessBoardCellArray  %Coordinates used are the "center of mass"
        ChessBoardCellSize = 0.037; %in meter (!)
        MyCBDisp %Class for visualization
        PointCloudOffset        % translstional offset between the camera and the chess board center
        debug
    end
    
    methods
        function obj = ChessBoard(MyCBDisp)

            storeAt = 0;
            for i = 1:8
                for j = 1:8
                    storeAt = storeAt + 1;
                    coors = obj.GetSquareCenter(i,j);
                    obj.ChessBoardCellArray(storeAt).CurrentPiece = 0;
                    obj.ChessBoardCellArray(storeAt).ColorOfPiece = '_';
                    obj.ChessBoardCellArray(storeAt).Xpos = coors(1);
                    obj.ChessBoardCellArray(storeAt).Ypos = coors(2);
                    obj.ChessBoardCellArray(storeAt).Zpos = coors(3);
                    obj.ChessBoardCellArray(storeAt).DetectedAsStillOccupied = 0;
                    obj.ChessBoardCellArray(storeAt).DetectedAsNewlyOccupied = 0;
                    obj.ChessBoardCellArray(storeAt).RGBDetectedAsChanged = 0;
                end
            end
            obj.MyCBDisp = MyCBDisp;
        end
        
        function SendPointCloudOffset(obj, PointCloudOffset)
            obj.PointCloudOffset = PointCloudOffset;  
        end
        
        
        function CompareDetectorWithBoard(obj, ClusterCoordinates, numClusters, WhitePiecesOnBoard)
            % loop over each (non)occupied field
            
            debugDist=[0];


            
%             figure(5);
%             clf('reset')
%             xlabel('X'); 
%             ylabel('Y'); 
%             zlabel('Z');
%             hold on;
%             % visualisation for debug
%             for j = 1:64
%                 % plot the center of the board field
%                 plot3(obj.ChessBoardCellArray(j).Xpos,obj.ChessBoardCellArray(j).Ypos,obj.ChessBoardCellArray(j).Zpos,'b.');
%                 text(obj.ChessBoardCellArray(j).Xpos+0.005,obj.ChessBoardCellArray(j).Ypos,obj.ChessBoardCellArray(j).Zpos, num2str(j), 'FontSize', 8 );
%             end
%             for i = 1:numClusters
%                 
%                 plot3(ClusterCoordinates(i,1) - obj.PointCloudOffset(1), ClusterCoordinates(i,2)- obj.PointCloudOffset(2), ClusterCoordinates(i,3)- obj.PointCloudOffset(3),'ro');
%                 text(ClusterCoordinates(i,1) - obj.PointCloudOffset(1), ClusterCoordinates(i,2)- obj.PointCloudOffset(2), ClusterCoordinates(i,3)- obj.PointCloudOffset(3), num2str(i), 'FontSize', 6 );
%             end
%             
%             % the x-axis of the RGB image is mirrored!
%             I3 = flipdim(WhitePiecesOnBoard ,2);           %# vertical flip
%             for x = 1:8
%                 for y = 1:8
%                     index = y+ ((x-1)*8);
%                     obj.ChessBoardCellArray(index).RGBDetectedAsChanged = WhitePiecesOnBoard(x,y);
%                     if ( obj.ChessBoardCellArray(index).RGBDetectedAsChanged == 1 )
%                        plot3(obj.ChessBoardCellArray(index).Xpos,obj.ChessBoardCellArray(index).Ypos,obj.ChessBoardCellArray(j).Zpos,'gx');
%                     end
%                 end
%             end
%             
%             
%             hold off;
            
            for j = 1:64
                obj.ChessBoardCellArray(j).DetectedAsOccupied = 0;
                obj.ChessBoardCellArray(j).DetectedAsStillOccupied = 0;
                obj.ChessBoardCellArray(j).DetectedAsNewlyOccupied = 0;
            end
            
            
            figure(6);
            title('')
            clf('reset');
            hold on;
            axis manual;
            axis([-0.15 0.15 -0.20 0.15 -5 5]);
            xlabel('X'); 
            ylabel('Y'); 
            zlabel('Z');
            
            restrict_legend_1 = 0;
            restrict_legend_2 = 0;
            restrict_legend_3 = 0;
            
            for j = 1:64
                
                % if there has been a piece on this field before, we check
                % if it is still occupied by comparing if any of the
                % clusters is here
                figure(6);
                if (restrict_legend_1 == 0)
                    plot3(obj.ChessBoardCellArray(j).Xpos,obj.ChessBoardCellArray(j).Ypos,obj.ChessBoardCellArray(j).Zpos,'b.','DisplayName','Chess field Pos');
                    restrict_legend_1 = 1;
                else
                    plot3(obj.ChessBoardCellArray(j).Xpos,obj.ChessBoardCellArray(j).Ypos,obj.ChessBoardCellArray(j).Zpos,'b.');
                end
                
                
                text(obj.ChessBoardCellArray(j).Xpos+0.005,obj.ChessBoardCellArray(j).Ypos,obj.ChessBoardCellArray(j).Zpos, num2str(j), 'FontSize', 8 );
                
                if (obj.ChessBoardCellArray(j).CurrentPiece > 0)
                    obj.ChessBoardCellArray(j).DetectedAsStillOccupied = 0;
                    for i = 1:numClusters
                        dis = sqrt( (ClusterCoordinates(i,1) - obj.PointCloudOffset(1) - obj.ChessBoardCellArray(j).Xpos)^2 + (ClusterCoordinates(i,2) - obj.PointCloudOffset(2) - obj.ChessBoardCellArray(j).Ypos)^2);
                        
                        if (dis <= obj.ChessBoardCellSize/2)
                            dis
                            figure(6);
                            obj.ChessBoardCellArray(j).DetectedAsStillOccupied = 1;
                            
                            if (restrict_legend_2 == 0)
                                plot3(ClusterCoordinates(i,1) - obj.PointCloudOffset(1), ClusterCoordinates(i,2)- obj.PointCloudOffset(2), ClusterCoordinates(i,3)- obj.PointCloudOffset(3),'go','DisplayName','Val. old Pos');
                                restrict_legend_2 = 1;
                            else
                                plot3(ClusterCoordinates(i,1) - obj.PointCloudOffset(1), ClusterCoordinates(i,2)- obj.PointCloudOffset(2), ClusterCoordinates(i,3)- obj.PointCloudOffset(3),'go');
                            end
                            
                            text(ClusterCoordinates(i,1) - obj.PointCloudOffset(1), ClusterCoordinates(i,2)- obj.PointCloudOffset(2), ClusterCoordinates(i,3)- obj.PointCloudOffset(3), num2str(i), 'FontSize', 6 );
                            
                            end
                    end
                else
                    % if it has not been previously occupied, we detect if
                    % it is newly occupied
                    obj.ChessBoardCellArray(j).DetectedAsStillOccupied = 0;
                    obj.ChessBoardCellArray(j).DetectedAsNewlyOccupied = 0;
                    for i = 1:numClusters
                        dis = sqrt( (ClusterCoordinates(i,1) - obj.PointCloudOffset(1) - obj.ChessBoardCellArray(j).Xpos)^2 + (ClusterCoordinates(i,2) - obj.PointCloudOffset(2) - obj.ChessBoardCellArray(j).Ypos)^2);
                        if (dis <= obj.ChessBoardCellSize/2)
                            
                            if (restrict_legend_3 == 0)
                                plot3(ClusterCoordinates(i,1) - obj.PointCloudOffset(1), ClusterCoordinates(i,2)- obj.PointCloudOffset(2), ClusterCoordinates(i,3)- obj.PointCloudOffset(3),'ro','DisplayName','Det. new Pos');
                                restrict_legend_3 = 1;
                            else
                                plot3(ClusterCoordinates(i,1) - obj.PointCloudOffset(1), ClusterCoordinates(i,2)- obj.PointCloudOffset(2), ClusterCoordinates(i,3)- obj.PointCloudOffset(3),'ro');
                             end
                            
                            
                            text(ClusterCoordinates(i,1) - obj.PointCloudOffset(1), ClusterCoordinates(i,2)- obj.PointCloudOffset(2), ClusterCoordinates(i,3)- obj.PointCloudOffset(3), num2str(i), 'FontSize', 6 );
                            obj.ChessBoardCellArray(j).DetectedAsNewlyOccupied = 1;
                        end
                    end
                end
            end
            legend({'Chess field Pos','Val. old Pos'},'Location','south','Orientation','horizontal');
            hold off;
        end
        
        function AnalyzePositionChanges(obj)
            
            % let's try to detect the start and end position of a board
            % move by analyzing our table of detector changes
            for i =1:numel(obj.ChessBoardCellArray)
                endPosVec(i) = obj.ChessBoardCellArray(i).DetectedAsNewlyOccupied;
                if (obj.ChessBoardCellArray(i).CurrentPiece > 0)
                    if (obj.ChessBoardCellArray(i).DetectedAsStillOccupied == 1)
                        startPosVec(i) = 0;
                    else
                        startPosVec(i) = 1;
                    end
                end
            end
            index_endPos = find(endPosVec > 0);
            index_startPos = find(startPosVec > 0);
            
            if (numel(index_startPos) == 1)
                startPos = index_startPos;
            else
               %we have a detector problem, since we apparently detected two starting positions of the field
               % ToDo here we need a manual override as  an error handling?
               a=5;
            end
            
            
            if (numel(index_endPos) == 1)
                endPos = index_endPos;
                
            else
                % ToDo if there is no new endpos, a piece has beeen taken and
                % so we need to analyze the RGB image of what happened
                
                 % possibility 1: A field that had been occupied by white piece is missing it's white piece
                for i =1:numel(obj.ChessBoardCellArray)
                    % we exclude the starting poaition of the move, because in
                    % case of a white move that obviously has changed, too.
                    if (i ~= startPos)
                        if ( (obj.ChessBoardCellArray(i).RGBDetectedAsChanged == 1) )
                            endPos = i;
                            break;
                        end
                    end
                end
                
                
                
                
%                 % possibility 1: A field that had been occupied by white piece is missing it's white piece
%                 for i =1:numel(obj.ChessBoardCellArray)
%                     % we exclude the starting poaition of the move, because in
%                     % case of a white move that obviously has changed, too.
%                     if (i ~= startPos)
%                         if ( (obj.ChessBoardCellArray(i).RGBDetectedAsWhite == 0) && strcmp(obj.ChessBoardCellArray(i).ColorOfPiece,'w'))
%                             endPos = i;
%                             break;
%                         end
%                     end
%                 end
%                 % possibility 2: A field that had been occupied by a black piece is now occupied by a white piece
%                 for i =1:numel(obj.ChessBoardCellArray)
%                     % we exclude the starting poaition of the move, because in
%                     % case of a white move that obviously has changed, too.
%                     if (i ~= startPos)
%                         if ( (obj.ChessBoardCellArray(i).RGBDetectedAsWhite == 1) && strcmp(obj.ChessBoardCellArray(i).ColorOfPiece,'b'))
%                             endPos = i;
%                             break;
%                         end
%                     end
%                 end
                
            end
            
            % here we replace the endpoint with the startpoint 
            obj.ChessBoardCellArray(endPos).CurrentPiece = obj.ChessBoardCellArray(startPos).CurrentPiece;
             obj.ChessBoardCellArray(endPos).ColorOfPiece = obj.ChessBoardCellArray(startPos).ColorOfPiece;
            
            % and we clear the starting field
            obj.ChessBoardCellArray(startPos).CurrentPiece = 0;
            obj.ChessBoardCellArray(startPos).ColorOfPiece = '_';         
            
        end
        
        function ExecuteMove(obj, sx, sy, ex, ey)
            % take sarting x,y and ending x,y and replaces the endposition
            % with the values of the startposition
            startPos = (sy-1)*8+sx;
            endPos   = (ey-1)*8+ex;
             % here we replace the endpoint with the startpoint 
            obj.ChessBoardCellArray(endPos).CurrentPiece = obj.ChessBoardCellArray(startPos).CurrentPiece;
            obj.ChessBoardCellArray(endPos).ColorOfPiece = obj.ChessBoardCellArray(startPos).ColorOfPiece;
            
            % and we clear the starting field
            obj.ChessBoardCellArray(startPos).CurrentPiece = 0;
            obj.ChessBoardCellArray(startPos).ColorOfPiece = '_';
        end
        
        function [MyPiece, MyColor] = LookUpPiece(obj, x, y)
            % function looks up the type of the chess piece on the board
            MyPos = (y-1)*8+x;
            
            MyColor = obj.ChessBoardCellArray(MyPos).ColorOfPiece;            
            if  (obj.ChessBoardCellArray(MyPos).CurrentPiece == 0)
                MyPiece = 'empty';
            end
            if  (obj.ChessBoardCellArray(MyPos).CurrentPiece == 1)
                MyPiece = 'pawn';
            end
            if  (obj.ChessBoardCellArray(MyPos).CurrentPiece == 4)
                MyPiece = 'rook';
            end
            if  (obj.ChessBoardCellArray(MyPos).CurrentPiece == 3)
                MyPiece = 'bishop';
            end
            if  (obj.ChessBoardCellArray(MyPos).CurrentPiece == 2)
                MyPiece = 'knight';
            end
            if  (obj.ChessBoardCellArray(MyPos).CurrentPiece == 6)
                MyPiece = 'king';
            end
            if  (obj.ChessBoardCellArray(MyPos).CurrentPiece == 5)
                MyPiece = 'queen';
            end
        end
        
        function MyAngle = SuggestPickUpAngle(obj, x, y)
            % This function checks the perimeter of a figure and scans for other tall figures in the vicinity.
            % If there are contenders, then a suitable pick-up angle for the robot is
            % suggested, so that no figures are toppled over
%            2    3    4       -----------> +y
%             \   |   /        |
%              \  |  /         |                 1: Angle is 0
%               \ | /          |                 2: Angle is 45
%                \|/           |                 3: Angle is 90
%            ----------- 1     |                 4: Angle is 270
%                /|\           v
%               / | \            +x
%              /  |  \
%             /   |   \
%                 
%             
%             Piece positions index
%             
%             3 4 5
%             2 0 6  
%             1 8 7  
            SumAngle_1 = obj.LUP(x,y-1) + obj.LUP(x,y+1); 
            SumAngle_2 = obj.LUP(x-1,y-1) + obj.LUP(x+1,y+1);
            SumAngle_3 = obj.LUP(x-1,y) + obj.LUP(x+1,y);
            SumAngle_4 = obj.LUP(x-1,y+1) + obj.LUP(x+1,y-1);
            
            MySums = [SumAngle_1,SumAngle_2, SumAngle_3, SumAngle_4];
            
            % we only need to bother if there is a queen and higher in the
            % vicinity, if not, we use the default angle of 0
            
            if ( max(MySums) >= 50)          
                index = find( MySums == min(MySums));           
                % what if we have multiple possibilities?
                if (numel(index) > 1)
                    if ismember(1,index)
                        % in case we can pick it up straight, let's do so
                        index = 1;  % enforced straight pick-up
                    else
                        % in case we have an oblique situation, pick the first
                        % choice
                        index = index(1);
                    end
                end
                % and get on with it ...
                
                %we have only one minima, so let's make our pick
                if (index == 1)
                    % we have potentially pieces at position 4,4,5,1,8,7
                    % so we pick up at 0 deg
                    MyAngle = 0;
                end
                if (index == 2)
                    % we have a big piece at position 4,5,6,8,1,2
                    % so we pick up at 315 deg
                    MyAngle = 315;
                end
                if (index == 3)
                    % we have a big piece at position 1,2,3,5,6,7
                    % so we pick up at either 90 deg or 270
                    % depending if the big piece is left or right to
                    % prevent collisions with the camera of the robot
                    if( obj.LUP(x,y-1) > obj.LUP(x,y+1) )
                        MyAngle = 90;
                    else
                        MyAngle = 270;
                    end
                end
                if (index == 4)
                    % we have a big piece at position 2,3,4,6,7,8
                    % so we pick up at 45 deg
                    MyAngle = 45;
                end
                
                %                 % the easy case, we have only
                %                 index = find( MySums == max(MySums))
                %                 if (index == 1)
                %                     % we have a big piece left or right off the pickup
                %                     % (so in position 2 or 6),
                %                     % so the grabber will pick up at 90 deg or at 270
                %                     % depending if the big piece is left or right to
                %                     % prevent collisions with the camera of the robot
                %                     if( obj.LUP(x,y-1) > obj.LUP(x,y+1) )
                %                         MyAngle = 90;
                %                     else
                %                         MyAngle = 270;
                %                     end
                %                 end
                %                 if (index == 2)
                %                     % we have a big piece at position 3 or 7
                %                     % so we pick up at 45deg
                %                     MyAngle = 45;
                %                 end
                %                 if (index == 3)
                %                     % we have a big piece at position 4 or 8
                %                     % so we pick up at 0 deg
                %                     MyAngle = 0;
                %                 end
                %                 if (index == 4)
                %                     % we have a big piece at position 1 or 5
                %                     % so we pick up at 0 deg
                %                     MyAngle = 315;
                %                 end  
            else
                % don't bother, only small pieces around the pickup point
                MyAngle = 0;
            end
        end
        
        function MyWeighting = LUP(obj, x, y)
            % work function for the angle look-up
            Weights = [0, 1, 10, 10, 10, 50, 100];
            
            MyWeighting = 0;
            if ( ((x>=1)&&(x<=8))&&((y>=1)&&(y<=8)))
                MyPos = (y-1)*8+x;
                
                MyWeighting =   Weights( (obj.ChessBoardCellArray(MyPos).CurrentPiece+1));
            else
                MyWeighting = 0;
            end
            
        end
        
        
        
        function coordinates = GetSquareCenter(obj, i,j)
            x_center = (i-1)*obj.ChessBoardCellSize + (obj.ChessBoardCellSize / 2) - 4*obj.ChessBoardCellSize;
            y_center = (j-1)*obj.ChessBoardCellSize + (obj.ChessBoardCellSize / 2) - 4*obj.ChessBoardCellSize;
            z_center = 0;
            coordinates = [x_center, y_center, z_center];
        end 
        
        function Initialize(obj)
            %set pawns
            for i = 1:8
                obj.ChessBoardCellArray((i-1)*8+2).CurrentPiece = 1;
                obj.ChessBoardCellArray((i-1)*8+2).ColorOfPiece = 'w';
            end
            for i = 1:8
                obj.ChessBoardCellArray((i-1)*8+7).CurrentPiece = 1;
                obj.ChessBoardCellArray((i-1)*8+7).ColorOfPiece = 'b';
            end
            
            %set rooks
            obj.ChessBoardCellArray(1).CurrentPiece = 4;
                obj.ChessBoardCellArray(1).ColorOfPiece = 'w';
            obj.ChessBoardCellArray(57).CurrentPiece = 4;
                obj.ChessBoardCellArray(57).ColorOfPiece = 'w';
            obj.ChessBoardCellArray(8).CurrentPiece = 4;
                obj.ChessBoardCellArray(8).ColorOfPiece = 'b';
            obj.ChessBoardCellArray(64).CurrentPiece = 4;
                obj.ChessBoardCellArray(64).ColorOfPiece = 'b';
            
            %set bishops
            obj.ChessBoardCellArray(17).CurrentPiece = 3;
                obj.ChessBoardCellArray(17).ColorOfPiece = 'w';
            obj.ChessBoardCellArray(41).CurrentPiece = 3;
                obj.ChessBoardCellArray(41).ColorOfPiece = 'w';
            obj.ChessBoardCellArray(24).CurrentPiece = 3;
                obj.ChessBoardCellArray(24).ColorOfPiece = 'b';
            obj.ChessBoardCellArray(48).CurrentPiece = 3;
                obj.ChessBoardCellArray(48).ColorOfPiece = 'b';
            
            %set knights
            obj.ChessBoardCellArray(9).CurrentPiece = 2;
                obj.ChessBoardCellArray(9).ColorOfPiece = 'w';
            obj.ChessBoardCellArray(49).CurrentPiece = 2;
                obj.ChessBoardCellArray(49).ColorOfPiece = 'w';
            obj.ChessBoardCellArray(16).CurrentPiece = 2;
                obj.ChessBoardCellArray(16).ColorOfPiece = 'b';
            obj.ChessBoardCellArray(56).CurrentPiece = 2;
                obj.ChessBoardCellArray(56).ColorOfPiece = 'b';
            
            %set king
            obj.ChessBoardCellArray(40).CurrentPiece = 6;
                obj.ChessBoardCellArray(40).ColorOfPiece = 'b';
            obj.ChessBoardCellArray(33).CurrentPiece = 6;
                obj.ChessBoardCellArray(33).ColorOfPiece = 'w';
            
            %set queen
            obj.ChessBoardCellArray(32).CurrentPiece = 5;
                obj.ChessBoardCellArray(32).ColorOfPiece = 'b';
            obj.ChessBoardCellArray(25).CurrentPiece = 5;
                obj.ChessBoardCellArray(25).ColorOfPiece = 'w';
            
            obj.debug = 5;
        end
         
        function chessMatrix = DisplayBoard(obj)
            positionAt = 1;
            chessMatrix = zeros(8,8);
            for i = 1:8
                for j = 1:8
                    piece = obj.ChessBoardCellArray(positionAt).CurrentPiece;
                    color = obj.ChessBoardCellArray(positionAt).ColorOfPiece;
                    obj.MyCBDisp.DisplayFigure(i, j, piece, color)
                    
                    positionAt = positionAt + 1;
%                     piece = obj.ChessBoardCellArray(positionAt).CurrentPiece;
                     chessMatrix(i,j) = piece
                end
            end
        end
    end
end