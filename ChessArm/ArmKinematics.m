classdef ArmKinematics < handle
    % --------------------
    % |                  |         inverse kenmatics coordinate system (world coordinates) 
    % |                  |
    % |                  |            ^
    % |    chessboard    |            | +y
    % |                  |            |         0 = origin at the center of the robot
    % |                  |            |             up is +z
    % |                  |            o------->
    % --------------------                    +x
    %        /  \
    %       |    | robot location
    %        \__/
    % % 
    %    o-----------> y-axis chess board
    %    |
    %    |     ^ +y robot 
    %    |     |             o = center of board at robot coors (x,y,z) = 0, 275,-68
    %    |     |
    %    |     o----> +x robot
    %    |   
    %    |
    %    v x-axis chess board
    %   index of the board is:
    %        upper left corner index 1 at x,y 1,1
    %        lower left corner index 8 at x,y 8,1
    %        lower right corner index 64 at x,y 8,8
    %        upper right corner index 56 at x,y 1,8
    %
    %  Robot joints and Hardware
    % 
    %                Ellbow to wrist distance
    %                        EtW = 227mm
    %                        
    %                   MMM RRR           MMM
    %                   MMM-RRR-----------MMM
    % distance joint    MMM RRR           MMM\  
    % axis o rot axis    /     rot            \   wrist to wrist roattion  WtWR = 15mm 
    % dja = 68.5mm      /      servo           \
    %                   \                      MM
    % desitance axis     \                     MM
    % shoulder to ellbow  \                      \
    % StE = 179mm          \                      \    wrist rotation to gripper tip WRtG = 107mm 
    %                       \
    %                        MMM
    %                        MMM
    %                        MMM
    %                         |    distance rotation base to acis should servo
    %                         |    RtS = 35mm
    %                        MMM
    %                        MMM
    %                        MMM
    properties
        EtW = 227;          % length of the limbs see drawing
        RtS = 39;           % length of the limbs see drawing
        StE = 179;          % length of the limbs see drawing
        WRtG = 107;         % length of the limbs see drawing
        WtWR = 15;          % length of the limbs see drawing
        dja = 68.5;         % length of the limbs see drawing
             
        L                   % this holds the link chain instance describing the arm
        MyArm               % this is the arm object itself
        MyPosDevice         % this is the position in motor coordinates (i.e. in degrees of each motor axis)
        MyPosWorld          % this is the position in motor coordinates (i.e. in degrees of each motor axis)
        
        MyServo             % class with the low level motor drivers (in device coordinates only)
        overwatchPose
        suspendPose         % these tow poses serve for a graceful landing
        suspendPose1
        neutralPose
        
        % center of the chessboard in 3D in robot coordinates
        cob_xr = 0;
        cob_yr = 275;
        cob_zr = -68;
        sizeField = 37;
        
        height_rook = 40;   % height of all chess peices in [mm]
        height_bishop = 45; % needed for placinga nd pick-up
        height_pawn = 30;
        height_knight = 38;
        height_king = 57;
        height_queen = 53;
        
    end
    
    methods
        function obj = ArmKinematics()
            % ============= Initialize the Link-Chain in Hardenberg-Levit notation to decribe our arm            
            % base plate rotation link, with offset to the shoulder servo
            L(1) = Revolute('d', obj.RtS, 'alpha', pi/2, 'offset', deg2rad(-90), 'qlim', [deg2rad(90) deg2rad(270)]);
            
            % shoulder servo link, which is mounted invered
            % carful, the phantomX has an L-shaped bracket as the upper arm and the rotation axis of the
            % ellbow servo is not aligened
            %
            % >>>>------- rotation axis of forearm
            % |26mm
            % |
            % x end of bracket
            % |                                         Therefore the default angle of the servo needs to be corrected
            % |36mm                                     offset = pi/2-atan(36/146)
            % |                146mm
            % X-------------------------------x shoulder servo
            % ellbow servo
            L(2) = Revolute('a', -obj.StE, 'offset', deg2rad(90), 'alpha', pi, 'qlim', [deg2rad(101.1) deg2rad(248.88)]);
            
            %ellbow servo link
            L(3) = Revolute('a', obj.dja, 'offset', deg2rad(0), 'alpha', -pi/2, 'qlim', [deg2rad(91.2) deg2rad(270)]);
            
            %forearm rotation link
            L(4) = Revolute('a', -10,'d', obj.EtW, 'alpha', pi/2, 'offset', deg2rad(-182), 'qlim', [deg2rad(19) deg2rad(345)]);
            
            % wrist link
            %L(5) = Revolute('d', 0, 'a', 0, 'offset', deg2rad(180-153.3), 'alpha', pi/2, 'qlim', [deg2rad(43) deg2rad(219)]);
            L(5) = Revolute('d', 0, 'a', 0, 'offset', deg2rad(180-164.75), 'alpha', pi/2, 'qlim', [deg2rad(102) deg2rad(280)]);
            
            %wrist rotation link
            L(6) = Revolute('d', obj.WRtG, 'alpha', pi/2, 'offset', deg2rad(180-150), 'qlim', [deg2rad(60) deg2rad(240)]);
            
            % create the robot
            obj.MyArm = SerialLink(L, 'name', 'Robby', 'manufacturer', 'Buuugsmashers ....');
            
            % init as meaningful starting values the rest position of the
            % robot
            obj.MyPosDevice  = [deg2rad(180) deg2rad(261.9) deg2rad(272.7) deg2rad(180) deg2rad(217) deg2rad(150) ];
            %Use inverse kinematics to update the world coordinates
            obj.MyPosWorld = obj.MyArm.fkine(obj.MyPosDevice);
            
            
            % priveledged poses for the joints
            obj.overwatchPose = [deg2rad(180) deg2rad(166.77) deg2rad(136.7) deg2rad(182.77) deg2rad(273.85) deg2rad(157.48) deg2rad(205)];        
            obj.suspendPose = [ deg2rad(180) deg2rad(262) deg2rad(269) deg2rad(180) deg2rad(210) deg2rad(150) deg2rad(204)];
            obj.suspendPose1 = [ deg2rad(180) deg2rad(262) deg2rad(270) deg2rad(180) deg2rad(220) deg2rad(150) deg2rad(204)];
            obj.neutralPose = [ deg2rad(180) deg2rad(262) deg2rad(260) deg2rad(180) deg2rad(200) deg2rad(150) deg2rad(204)];
        end
        %243
        function Close(obj)
            obj.MyServo.Close();
        end
        
        function StrobeLEDs(obj)
            for i=0:5
                pause('on');
                obj.MyServo.ToggleLED(1);
                pause(0.2);
                obj.MyServo.ToggleLED(0);
                pause(0.2);
            end
        end
        
        function StartUpRobot(obj)
           % init communication with the motors ======================================
            obj.MyServo = SixDOFDynamixelDriver();
            % ENABLE TORQUE ================================
            error = obj.MyServo.ToggleTorque(1);
            % SET DEFAULT SPEED ===============
            error = obj.MyServo.SetDefaultSpeed();
            % lift the gripper in order to prevent entanglements with the base rotation
            error = obj.MyServo.SetSingleGoalPosition(5, deg2rad(157), 1);
            pause(5);
        end
        
        function outputArg = PowerDownRobot(obj)
           % set the robot in parking position
             error = obj.MyServo.SetGoalPositionSyncMove(obj.suspendPose1,1,1, 'precision');
             pause(3);
            % DISABLE TORQUE ================================
            error = obj.MyServo.ToggleTorque(0);
        end 
        
        function error = SuspendRobot(obj)
           % set the robot in parking position
            error = obj.MyServo.SetGoalPositionSyncMove(obj.suspendPose,1,1, 'precision');
            pause(3);
            error = obj.MyServo.SetGoalPositionSyncMove(obj.suspendPose1,1,1, 'precision');
            pause(1);
            % DISABLE TORQUE ================================
            error = obj.MyServo.ToggleTorque(0);
        end     
        
        function error = WakeUpFromSuspend(obj)
            % ENABLE TORQUE ================================
            error = obj.MyServo.ToggleTorque(1); 
        end 
      
        function error = SetOverwatch(obj)
            % move to overwatch position
            error = obj.MyServo.SetGoalPositionSyncMove(obj.overwatchPose,1,1, 'precision');
        end
        
        function error = SetNeutralPose(obj)
            % move to overwatch position
            error = obj.MyServo.SetGoalPositionSyncMove(obj.neutralPose,1,1, 'precision');
        end

        function error = MoveChesspieceOnBoard(obj, piece, initX, initY, finalX, finalY, varargin)
            % rotrec is a rotation recommendation to grab a piece angular
            % in case tehre are larger pieces directly next to the place of
            % intervention. This should limit bumping in other pieces
            % it is optionally passed as a varargin
            switch nargin
                case 6 
                    initRotRec = 0; 
                    finalRotrec = 0;
                case 7
                    initRotRec = varargin{1}; 
                    finalRotrec = varargin{1};
                case 8
                    initRotRec = varargin{1}; 
                    finalRotrec = varargin{2};
            end
            % sanity check
            if ((initX > 0) && (initX < 9) && (initY > 0) && (initY < 9) && ...
                    (finalX > 0) && (finalX < 9) && (finalY > 0) && (finalY < 9))
                
                % dtermine the height of the move by the type of the piece
                if strcmp(piece,'knight')
                    height_piece = obj.height_knight;
                end
                if strcmp(piece,'bishop')
                    height_piece = obj.height_bishop;
                end
                if strcmp(piece,'king')
                    height_piece = obj.height_king;
                end
                if strcmp(piece,'queen')
                    height_piece = obj.height_queen;
                end
                if strcmp(piece,'rook')
                    height_piece = obj.height_rook;
                end
                if strcmp(piece,'pawn')
                    height_piece = obj.height_pawn;
                end
                % calculate the robot coordinates for the required movesmoves
                % keep in mind the input is in chess-boar coordinates, while
                % we need robot coordinates
                sposxr = obj.cob_xr + (initY*37)-(4.5*obj.sizeField); %(4.5*obj.sizeField)
                sposyr = obj.cob_yr - (initX*37)+(4.5*obj.sizeField); %(4.5*obj.sizeField)
                fposxr = obj.cob_xr + (finalY*37)-(4.5*obj.sizeField);%(4.5*obj.sizeField)
                fposyr = obj.cob_yr - (finalX*37)+(4.5*obj.sizeField);%(4.5*obj.sizeField)
                sposzr = obj.cob_zr + height_piece;
                fposzr = obj.cob_zr + height_piece;
                % execute the moves, pick-up first
                test=obj.FetchAt3D(sposxr, sposyr, sposzr, initRotRec);
                % and set-down at the new position
                test=obj.PlaceAt3D(fposxr, fposyr, fposzr, finalRotrec);
                % retreat into  a neutral pose
                %obj.SetNeutralPose();
                error = 0;
            else 
                error = 1;
            end
        end
        
        
        function error = FetchAt3D(obj, x, y, z, varargin)
            % rotrec is a rotation recommendation to grab a piece angular
            % in case tehre are larger pieces directly next to the place of
            % intervention. This should limit bumping in other pieces
            % it is optionally passed as a varargin
            switch nargin
                case 4 
                    RotRec = 0; 
                case 5
                    RotRec = varargin{1} 
            end
            %move the grabber over the position
            obj.MyServo.OpenGrabber();
            obj.MoveTo3D( x, y, 70, RotRec);
            obj.PrecisionMoveTo3D( x, y, z, RotRec);
            obj.MyServo.CloseGrabber2();
            obj.PrecisionMoveTo3D( x, y, 70, RotRec);
            error = 0;
        end
        
        function error = PlaceAt3D(obj, x, y, z, varargin)
            % rotrec is a rotation recommendation to grab a piece angular
            % in case tehre are larger pieces directly next to the place of
            % intervention. This should limit bumping in other pieces
            % it is optionally passed as a varargin
            switch nargin
                case 4 
                    RotRec = 0; 
                case 5
                    RotRec = varargin{1}; 
            end      
            %move the grabber over the position
            obj.MoveTo3D( x, y, 70, RotRec);
            obj.PrecisionMoveTo3D( x, y, z, RotRec);
            obj.MyServo.OpenGrabber();
            obj.PrecisionMoveTo3D( x, y, 70, RotRec);
            error = 0;
        end
       
      
        function error = PrecisionMoveTo3D(obj, x, y, z, varargin)
            %this method keeps the gripper vertical and approaches all
            %positions "from above"
            
            % rotrec is a rotation recommendation to grab a piece angular
            % in case tehre are larger pieces directly next to the place of
            % intervention. This should limit bumping in other pieces
            % it is optionally passed as a varargin
            switch nargin
                case 4 
                    RotRec = 0; 
                case 5
                    RotRec = varargin{1}; 
            end   
            refpos=[deg2rad(180), deg2rad(212), deg2rad(225), deg2rad(180), deg2rad(232), deg2rad(150+RotRec)];
            Tref = obj.MyArm.fkine(refpos);
            
            Tn = Tref;
            Tn(1,4)= x;
            Tn(2,4)= y;
            Tn(3,4)= z; 
            % translate from world to device coordinates
            q = obj.MyArm.ikcon(Tn, obj.MyPosDevice);
            
            % use forwards kinetics to check if we can reach this position
            Tres = obj.MyArm.fkine(q);
            sum((Tn - Tres), 'all');
            %obj.MyArm.plot( q );
            obj.MyServo.grabberOverride = 1; 
            error = obj.MyServo.SetGoalPositionSyncMove(q,1,1, 'precision');
        end    
        
        function error = MoveTo3D(obj, x, y, z, varargin)
            %this method keeps the gripper vertical and approaches all
            %positions "from above"
            
            % rotrec is a rotation recommendation to grab a piece angular
            % in case tehre are larger pieces directly next to the place of
            % intervention. This should limit bumping in other pieces
            % it is optionally passed as a varargin
            switch nargin
                case 4 
                    RotRec = 0; 
                case 5
                    RotRec = varargin{1}; 
            end   
            refpos=[deg2rad(180), deg2rad(212), deg2rad(225), deg2rad(180), deg2rad(232), deg2rad(150+RotRec)];
            Tref = obj.MyArm.fkine(refpos);
            
            Tn = Tref;
            Tn(1,4)= x;
            Tn(2,4)= y;
            Tn(3,4)= z; 
            % translate from world to device coordinates
            q = obj.MyArm.ikcon(Tn, obj.MyPosDevice);
            
            % use forwards kinetics to check if we can reach this position
            Tres = obj.MyArm.fkine(q);
            sum((Tn - Tres), 'all');
            %obj.MyArm.plot( q );
            obj.MyServo.grabberOverride = 1; 
            error = obj.MyServo.SetGoalPositionSyncMove(q,1,1, 'speed');
        end
    end
end






















