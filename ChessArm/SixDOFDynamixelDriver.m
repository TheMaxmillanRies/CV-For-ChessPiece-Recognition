classdef SixDOFDynamixelDriver
    %UNTITLED3 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Control table address
        ADDR_MX_TORQUE_ENABLE       = 24;           % Control table address is different in Dynamixel model
        ADDR_MX_GOAL_POSITION       = 30;
        ADDR_MX_MOVING_SPEED        = 32;
        ADDR_MX_PRESENT_POSITION    = 36;
        ADDR_MX_PRESENT_LOAD        = 40;
        ADDR_MX_P_GAIN              = 28;
        ADDR_MX_I_GAIN              = 27;
        ADDR_MX_D_GAIN              = 26;
        ADDR_MX_LED                 = 25;
        ADDR_MX_TORQUE_LIMIT        = 14;
        ADDR_MX_MAX_TORQUE          = 34;
        
        % Data Byte Length
        LEN_MX_GOAL_POSITION        = 2;
        LEN_MX_MOVING_SPEED         = 2;
        LEN_MX_PRESENT_POSITION     = 2;
        LEN_MX_PRESENT_LOAD         = 2;
        LEN_MX_P_GAIN               = 2;
        LEN_MX_I_GAIN               = 1;
        LEN_MX_D_GAIN               = 1;
        LEN_MX_LED                  = 1;
        
        % Protocol version
        PROTOCOL_VERSION            = 1.0;          % See which protocol version is used in the Dynamixel
        
        % Default setting
        DXL1_ID                     = 1;            % Dynamixel#1 ID: 1 base plate rotation
        DXL2_ID                     = 2;            % Dynamixel#2 ID: 2 shoulder joint
        DXL3_ID                     = 3;            % Dynamixel#3 ID: 3 ellbow joint
        DXL4_ID                     = 4;            % Dynamixel#4 ID: 4 arm rotation
        DXL5_ID                     = 5;            % Dynamixel#5 ID: 5 wrist joint
        DXL6_ID                     = 6;            % Dynamixel#6 ID: 6 wrist rotation
        DXL7_ID                     = 7;            % Dynamixel#7 ID: 7 grabber
        DXL8_ID                     = 8;            % Dynamixel#8 ID: 8 doubled shoulder servo in slave mode (hardware mode MX-106)
        DXL9_ID                     = 9;            % Dynamixel#9 ID: 9 MX-64 slave servo in the shoulder joint in software slave mode. 
        
        
        SERVO_TYPE = {'MX-28'; 'MX-106'; 'MX-64'; 'MX-28'; 'MX-28'; 'AX-18'; 'AX-12'; 'MX-106'; 'MX-64'};
        AngleToTicks;
        
        DXL_ID                      = [1,2,3,4,5,6,7,8,9];
        BAUDRATE                    = 1000000;
        DEVICENAME                  = 'COM3';       % Check which port is being used on your controller
        TORQUE_ENABLE               = 1;            % Value for enabling the torque
        TORQUE_DISABLE              = 0;            % Value for disabling the torque
                               % ex) Windows: 'COM1'   Linux: '/dev/ttyUSB0' Mac: '/dev/tty.usbserial-*'

        COMM_SUCCESS                = 0;            % Communication Success result value
        COMM_TX_FAIL                = -1001;        % Communication Tx Failed
        
        DEFAULTMAXSPEED_AX18 = 35;
        DEFAULTMAXSPEED_AX12 = 50;
        DEFAULTMAXSPEED_MX28 = 40;
        DEFAULTMAXSPEED_MX28_Base = 30;
        DEFAULTMAXSPEED_MX64 = 30;
        DEFAULTMAXSPEED_MX106 = 30;
        DEFAULT_PGAIN_MX = 25;
        DEFAULT_IGAIN_MX = 30;
        DEFAULT_DGAIN_MX = 15;
        
        DEFAULT_PGAIN_PRECISION_MX = 20;
        DEFAULT_IGAIN_PRECISION_MX = 30;
        DEFAULT_DGAIN_PRECISION_MX = 0;
        
        DXL_MOVING_STATUS_THRESHOLD = 15;           % Dynamixel moving status threshold
        port_num = 0;
        lib_name;
        group_num_pos = 0;
        group_num_speed = 0;
        group_p_gain = 0;
        group_i_gain = 0;
        group_d_gain = 0;
        group_led = 0;
        p_servo;                                % polynom holding the calibration of the set-point of the second ellbow servo vs the master servo
        CurrentPosition;
        
        grabberOverride = 0;
        
    end
    
    methods
        
        % =============== constructor, inits communication and default settings ===========================
        function obj = SixDOFDynamixelDriver(inputArg1,inputArg2)
            
            % load dynamixel libraries
            if strcmp(computer, 'PCWIN')
                obj.lib_name = 'dxl_x86_c';
            elseif strcmp(computer, 'PCWIN64')
                obj.lib_name = 'dxl_x64_c';
            elseif strcmp(computer, 'GLNX86')
                obj.lib_name = 'libdxl_x86_c';
            elseif strcmp(computer, 'GLNXA64')
                obj.lib_name = 'libdxl_x64_c';
            elseif strcmp(computer, 'MACI64')
                obj.lib_name = 'libdxl_mac_c';
            end
            
            % Load Libraries
            if ~libisloaded(obj.lib_name)
                [notfound, warnings] = loadlibrary(obj.lib_name, 'dynamixel_sdk.h', 'addheader', 'port_handler.h', 'addheader', 'packet_handler.h', 'addheader', 'group_sync_write.h');
            end
            
            % Initialize PortHandler Structs
            % Set the port path
            % Get methods and members of PortHandlerLinux or PortHandlerWindows
            port_num = portHandler(obj.DEVICENAME);
            
            % Initialize PacketHandler Structs
            packetHandler();
            
            obj.group_num_pos   = groupSyncWrite(obj.port_num, obj.PROTOCOL_VERSION, obj.ADDR_MX_GOAL_POSITION, obj.LEN_MX_GOAL_POSITION);
            obj.group_num_speed = groupSyncWrite(obj.port_num, obj.PROTOCOL_VERSION, obj.ADDR_MX_MOVING_SPEED, obj.LEN_MX_MOVING_SPEED);
            obj.group_p_gain = groupSyncWrite(obj.port_num, obj.PROTOCOL_VERSION, obj.ADDR_MX_P_GAIN, obj.LEN_MX_P_GAIN);
            obj.group_i_gain = groupSyncWrite(obj.port_num, obj.PROTOCOL_VERSION, obj.ADDR_MX_I_GAIN, obj.LEN_MX_I_GAIN);
            obj.group_d_gain = groupSyncWrite(obj.port_num, obj.PROTOCOL_VERSION, obj.ADDR_MX_D_GAIN, obj.LEN_MX_D_GAIN);
            obj.group_led = groupSyncWrite(obj.port_num, obj.PROTOCOL_VERSION, obj.ADDR_MX_LED, obj.LEN_MX_LED);
            
            result = obj.COMM_TX_FAIL;             % Communication result
            dxl_addparam_result = false;                % AddParam result
            
            L = length( obj.SERVO_TYPE ); 
            for i=1:L
                if (strcmp(obj.SERVO_TYPE{i}, 'MX-28') || strcmp(obj.SERVO_TYPE{i}, 'MX-64') || strcmp(obj.SERVO_TYPE{i}, 'MX-106'))
                    obj.AngleToTicks(i) = 4096.0 / 2 / pi;
                else
                    obj.AngleToTicks(i) = 1024.0 / (300 / 360 * 2 * pi);
                end
            end
                
                % Open port
                if (openPort(obj.port_num))
                    fprintf('Succeeded to open the port!\n');
            else
                unloadlibrary(obj.lib_name);
                fprintf('Failed to open the port!\n');
                input('Press any key to terminate...\n');
                return;
            end
            % Set port baudrate
            if (setBaudRate(obj.port_num, obj.BAUDRATE))
                fprintf('Succeeded to change the baudrate!\n');
            else
                unloadlibrary(obj.lib_name);
                fprintf('Failed to change the baudrate!\n');
                input('Press any key to terminate...\n');
                return;
            end
            
            % set the default PID settings to the servos
            obj.SetPID('speed');  
        
            % initialize the callibration for the slave mode of the secon
            % MX-64 servo in software slave mode
            %obj.p_servo = [0.9981, 9];
            obj.p_servo = [0.9978,   16.1358];
            
            
            % Carbon Copy of the current motor position
            CurrentPosition = ReadServoPos(obj);
        end
        
        % ========================================== Cleanup: unload drivers and disconnect ==========================================
        function  Close(obj)
            % Close port
            closePort(obj.port_num);
            
            % Unload Library
            unloadlibrary(obj.lib_name);
            
            close all;
            clear all;
        end
        
         
        % ========================================== Set the PID controller of the MX servos ==========================================
        function  SetPID(obj, mode)
            % copy the PID gains into the MX servos
            for i=1:numel(obj.SERVO_TYPE)
                if (strcmp(obj.SERVO_TYPE{i}, 'MX-28') || strcmp(obj.SERVO_TYPE{i}, 'MX-64') || strcmp(obj.SERVO_TYPE{i}, 'MX-106'))
                    
                    if strcmp(mode, 'speed')
                        dxl_addparam_result = groupSyncWriteAddParam(obj.group_p_gain, obj.DXL_ID(i), obj.DEFAULT_PGAIN_MX, obj.LEN_MX_P_GAIN);
                    else
                        dxl_addparam_result = groupSyncWriteAddParam(obj.group_p_gain, obj.DXL_ID(i), obj.DEFAULT_PGAIN_PRECISION_MX, obj.LEN_MX_P_GAIN);
                    end
                    if dxl_addparam_result == true
                        if strcmp(mode, 'speed')
                            dxl_addparam_result = groupSyncWriteAddParam(obj.group_i_gain, obj.DXL_ID(i), obj.DEFAULT_IGAIN_MX, obj.LEN_MX_I_GAIN);
                        else
                            dxl_addparam_result = groupSyncWriteAddParam(obj.group_i_gain, obj.DXL_ID(i), obj.DEFAULT_IGAIN_PRECISION_MX, obj.LEN_MX_I_GAIN);
                            
                        end
                    end
                    if dxl_addparam_result == true
                        if strcmp(mode, 'speed')
                            dxl_addparam_result = groupSyncWriteAddParam(obj.group_d_gain, obj.DXL_ID(i), obj.DEFAULT_DGAIN_MX, obj.LEN_MX_D_GAIN);
                        else
                            dxl_addparam_result = groupSyncWriteAddParam(obj.group_d_gain, obj.DXL_ID(i), obj.DEFAULT_DGAIN_PRECISION_MX, obj.LEN_MX_D_GAIN);
                        end
                    end
                    if dxl_addparam_result ~= true
                        fprintf('[ID:%03d] groupSyncWrite PID failed', obj.DXL_ID(i));
                        dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
                        return;
                    else
                        dxl_error = 0;
                    end
                end
            end
            % Syncwrite PID settings
            groupSyncWriteTxPacket(obj.group_p_gain);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result == obj.COMM_SUCCESS
                groupSyncWriteTxPacket(obj.group_i_gain);
                dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            end
            if dxl_comm_result == obj.COMM_SUCCESS
                groupSyncWriteTxPacket(obj.group_d_gain);
                dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            end
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            end
            % Clear syncwrite parameter storage
            groupSyncWriteClearParam(obj.group_p_gain);
            groupSyncWriteClearParam(obj.group_i_gain);
            groupSyncWriteClearParam(obj.group_d_gain); 
        end
        
        % ========================================== Toggle the servo LEDs ==========================================
 
        function  dxl_error = ToggleLED(obj, toggle)
            for i=1:numel(obj.SERVO_TYPE)
                dxl_addparam_result = groupSyncWriteAddParam(obj.group_led, obj.DXL_ID(i), toggle, obj.LEN_MX_LED);
                if dxl_addparam_result ~= true
                    fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                    dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
                    return;
                else
                    dxl_error = 0;
                end
            end
            % Syncwrite goal position
            groupSyncWriteTxPacket(obj.group_led);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
                dxl_error = dxl_comm_result;
            end
            % Clear syncwrite parameter storage
            groupSyncWriteClearParam(obj.group_led);
        end
        
        % ========================================== Lock and unlock the grabber from tranjectory moves ==========================================
        function LockGrabber(obj)
            obj.grabberOverride = 1;
        end
        
        function UnlockGrabber(obj)
            obj.grabberOverride = 0;
        end
        
        % ==========================================Open and close the grabber====================================================================
        
        % ==== open
        function OpenGrabber(obj)
            
            OpeningPos = 800;
            OpeningSpeed = 150;
            
           % Set the speed for swift opeing of the grabber
            write2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_MOVING_SPEED, OpeningSpeed);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
            end 

            % Write position to grabber for opening
            write2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_GOAL_POSITION, OpeningPos);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
            end
            
            %wait until we are in position
            while 1
                currentPos = obj.ReadServoPos();
                dist = 0;
                dist =  abs(OpeningPos - currentPos(7));
                % dist % DEBUG
                if ~(dist > 3)
                    break;
                end
            end
        end
        
        % close grabber on a different load control============
        function CloseGrabber2(obj)
            OpeningPos = 850;
            ClosingPos = 320;
            ClosingSpeed = 40;
            MaxTorque = 400;
            TorqueLimit = 200;
            
            % Set the speed for swift opeing of the grabber
            write2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_MOVING_SPEED, ClosingSpeed);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
            end
            
            % Set the max torque limit of the grabber
            write2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_MAX_TORQUE, MaxTorque);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
            end
            
            % Set the stop-load of the grabber
            write2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_TORQUE_LIMIT, MaxTorque);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
            end
            
            % Write position to grabber for opening
            write2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_GOAL_POSITION,  320);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
            end
            
            %wait until we are in position but bail if we are stuck
            for j=1:50
                currentPos = obj.ReadServoPos();
                dist = 0;
                dist =  abs((ClosingPos) - currentPos(7));
                % dist % DEBUG
                if ~(dist > 3)
                    break;
                end
            end
            
        end
        
        % close ============
        function CloseGrabber(obj)
            
            GripperLoad = 0;
            OpeningPos = 800;
            ClosingSpeed = 80;
            
            currentPos = obj.ReadServoPos();
            Debug1 = [currentPos(7)];
            Debug2 = [0];
            
            % Set the speed for swift opeing of the grabber
            write2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_MOVING_SPEED, ClosingSpeed);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            elseif dxl_error ~= 0
                fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
            end 
            
            for i=1:20
                
                % Write position to grabber for opening
                write2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_GOAL_POSITION,  OpeningPos-i*20);
                dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
                dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
                if dxl_comm_result ~= obj.COMM_SUCCESS
                    fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
                elseif dxl_error ~= 0
                    fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
                end
                
                %wait until we are in position but bail if we are stuck
                for j=1:100
                    currentPos = obj.ReadServoPos();
                    dist = 0;
                    dist =  abs((OpeningPos-i*20) - currentPos(7));
                    % dist % DEBUG
                    if ~(dist > 3)
                        break;
                    end  
                end
                % obligatory delay to let the current settel
                obj.delay(0.35);
                
                % averaging over the load measurement (very noisy)
                dxl2_present_load = 0;
                for j=1:10
                    dxl2_present_load = dxl2_present_load + read2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(7), obj.ADDR_MX_PRESENT_LOAD)
                    dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
                    dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
                    if dxl_comm_result ~= obj.COMM_SUCCESS
                        fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
                    elseif dxl_error ~= 0
                        fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
                    end
                end
                dxl2_present_load = dxl2_present_load / 10;
                
                % get rid of oiutliers
                if (dxl2_present_load > 1000) 
                    dxl2_present_load = 0;
                end
                
                Debug1 = [Debug1, currentPos(7)];
                Debug2 = [Debug2, dxl2_present_load];
            
                
                if (dxl2_present_load > 80)
                    break;
                end
            end    
            
%             figure(1);
%             plot(Debug1, Debug2);
%             a=5
            
        end
        
        function delay(obj, t)
            tic;
            while toc < t
            end
        end
        
        % ========================================== Enable Disable Torque on Servos ==========================================
        function dxl_error = ToggleTorque(obj, OnOff)
            
            for i=1:numel(obj.SERVO_TYPE)
                % Loop over all servos for activation
                write1ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(i), obj.ADDR_MX_TORQUE_ENABLE, OnOff);
                dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
                dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
                if dxl_comm_result ~= obj.COMM_SUCCESS
                    fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
                elseif dxl_error ~= 0
                    fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
                else
                    fprintf('Dynamixel has been successfully connected \n');
                end
            end
        end
        % ========================================== Enable Disable Torque on Servos ==========================================
        function dxl_error = SetDefaultSpeed(obj)
            
            for i=1:numel(obj.SERVO_TYPE)
                if (strcmp(obj.SERVO_TYPE{i}, 'AX-18'))
                    dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_AX18, obj.LEN_MX_MOVING_SPEED);
                else if (strcmp(obj.SERVO_TYPE{i}, 'AX-12'))
                        dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_AX12, obj.LEN_MX_MOVING_SPEED);
                    else if (strcmp(obj.SERVO_TYPE{i}, 'MX-28') )
                            dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_MX28, obj.LEN_MX_MOVING_SPEED);
                        else if (strcmp(obj.SERVO_TYPE{i}, 'MX-64') )
                                dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_MX64, obj.LEN_MX_MOVING_SPEED);
                            else if (strcmp(obj.SERVO_TYPE{i}, 'MX-106'))
                                    dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_MX106, obj.LEN_MX_MOVING_SPEED);
                                end
                            end
                        end
                    end
                end
                if dxl_addparam_result ~= true
                    fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                    dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
                    return;
                else
                    dxl_error = 0;
                end
            end
            % Syncwrite goal position
            groupSyncWriteTxPacket(obj.group_num_speed);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            end
            % Clear syncwrite parameter storage
            groupSyncWriteClearParam(obj.group_num_speed);
        end
        
        % ========================================== Enable Disable Torque on Servos ==========================================
        function dxl_error = SetSpeed(obj, SpeedScaling)
           
            
            % switch to not touch the grabber during moves
            if(obj.grabberOverride == 1)
                MaxServoIndex = 6;
            else
                MaxServoIndex = 7;
            end
            
            for i=1:numel(obj.SERVO_TYPE)
                if (strcmp(obj.SERVO_TYPE{i}, 'AX-18'))
                    dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_AX18 * SpeedScaling(i), obj.LEN_MX_MOVING_SPEED);
                else if (strcmp(obj.SERVO_TYPE{i}, 'AX-12'))
                        dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_AX12* SpeedScaling(i), obj.LEN_MX_MOVING_SPEED);
                    else if (strcmp(obj.SERVO_TYPE{i}, 'MX-28') )
                            dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_MX28* SpeedScaling(i), obj.LEN_MX_MOVING_SPEED);
                        else if (strcmp(obj.SERVO_TYPE{i}, 'MX-64') )
                                dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_MX64* SpeedScaling(i), obj.LEN_MX_MOVING_SPEED);
                            else if (strcmp(obj.SERVO_TYPE{i}, 'MX-106'))
                                    dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), obj.DEFAULTMAXSPEED_MX106* SpeedScaling(i), obj.LEN_MX_MOVING_SPEED);
                                end
                            end
                        end
                    end
                end
                if dxl_addparam_result ~= true
                    fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                    dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
                    return;
                else
                    dxl_error = 0;
                end
            end
            % Syncwrite goal position
            groupSyncWriteTxPacket(obj.group_num_speed);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            end
            % Clear syncwrite parameter storage
            groupSyncWriteClearParam(obj.group_num_speed);
        end
         
        % ========================================== set single Servo goal position and go ================================== 
        function dxl_error = SetSingleGoalPosition(obj, Servo_ID, GoalPos, Convert_Angle_to_Ticks)
            
            if(Convert_Angle_to_Ticks == 1)
                    GoalPos = GoalPos * obj.AngleToTicks(Servo_ID);
            end
            
            dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_pos, obj.DXL_ID(Servo_ID), GoalPos, obj.LEN_MX_GOAL_POSITION);
            if dxl_addparam_result ~= true
                fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(Servo_ID));
                dxl_error = fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(Servo_ID));
                return;
            else
                dxl_error = 0;
            end
            % software slaving of the second ellbow servo
            if (Servo_ID==3)
                % look up the goal positin of servo 9 from the setpoint
                % of servo 3
                f = polyval(obj.p_servo, GoalPos);
                % and set it as the goalpos for servo 9
                dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_pos, obj.DXL_ID(9), f, obj.LEN_MX_GOAL_POSITION);
                if dxl_addparam_result ~= true
                    fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(9));
                    dxl_error = fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(9));
                    return;
                else
                    dxl_error = 0;
                end
            end
            % Syncwrite goal position of all servos
            groupSyncWriteTxPacket(obj.group_num_pos);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            end
            % Clear syncwrite parameter storage
            groupSyncWriteClearParam(obj.group_num_pos);
        end
            
        % ========================================== set Servo goal position and go ==========================================
        function dxl_error = SetGoalPosition(obj, GoalPos, WaitForCompletion, Convert_Angle_to_Ticks)
            
            % switch to not touch the grabber during moves
            if(obj.grabberOverride == 1)
                MaxServoIndex = 6;
            else
                MaxServoIndex = 7;
            end
            
            if(Convert_Angle_to_Ticks == 1)
                for i=1:MaxServoIndex
                    GoalPos(i) = GoalPos(i) * obj.AngleToTicks(i);
                end
            end
               
            for i=1:MaxServoIndex
                dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_pos, obj.DXL_ID(i), GoalPos(i), obj.LEN_MX_GOAL_POSITION);
                if dxl_addparam_result ~= true
                    fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                    dxl_error = fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                    return;
                else
                    dxl_error = 0;
                end               
                % software slaving of the second ellbow servo
                if (i==3)
                    % look up the goal positin of servo 9 from the setpoint
                    % of servo 3
                    f = polyval(obj.p_servo, GoalPos(i));
                    % and set it as the goalpos for servo 9
                    dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_pos, obj.DXL_ID(9), f, obj.LEN_MX_GOAL_POSITION);
                    if dxl_addparam_result ~= true
                        fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(9));
                        dxl_error = fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(9));
                        return;
                    else
                        dxl_error = 0;
                    end
                end
            end
            % Syncwrite goal position of all servos
            groupSyncWriteTxPacket(obj.group_num_pos);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            end
            % Clear syncwrite parameter storage
            groupSyncWriteClearParam(obj.group_num_pos);  
      
            % wait for the completion of the move (optional)
            if (WaitForCompletion == 1)
                while 1
                    currentPos = obj.ReadServoPos();
                    dist = 0;
                    for i = 1:MaxServoIndex
                        dist = dist + abs(GoalPos(i) - currentPos(i));
                    end
                    % dist % DEBUG
                    if ~(dist > obj.DXL_MOVING_STATUS_THRESHOLD*7)
                        break;
                    end
                    
                end
            end
            
        end
        
        
         % ========================================== set Servo goal position and go ==========================================
        function dxl_error = SetGoalPositionTrajectorySyncMove(obj, GoalPosTrajectory, NoInterpolSteps, WaitForCompletion, Convert_Angle_to_Ticks)
        
            
            index = 1:2;
            for i=1:NoInterpolSteps
              
               y1 = [ GoalPosTrajectory(1,1) GoalPosTrajectory(2,1) ];
               y2 = [ GoalPosTrajectory(1,2) GoalPosTrajectory(2,2) ];
               y3 = [ GoalPosTrajectory(1,3) GoalPosTrajectory(2,3) ];
               y4 = [ GoalPosTrajectory(1,4) GoalPosTrajectory(2,4) ];
               y5 = [ GoalPosTrajectory(1,5) GoalPosTrajectory(2,5) ];
               y6 = [ GoalPosTrajectory(1,6) GoalPosTrajectory(2,6) ];
               
               TrajectorySegment = [ interp1(index,y1,i/NoInterpolSteps+1) interp1(index,y2,i/NoInterpolSteps+1) interp1(index,y3,i/NoInterpolSteps+1) ...
                                     interp1(index,y4,i/NoInterpolSteps+1) interp1(index,y5,i/NoInterpolSteps+1) interp1(index,y6,i/NoInterpolSteps+1)]
      
              error =  obj.SetGoalPositionSyncMove(TrajectorySegment, WaitForCompletion, Convert_Angle_to_Ticks)
            end
        
        end
        
         % ========================================== set Servo goal position and go ==========================================
        function dxl_error = SetGoalPositionSyncMove(obj, GoalPos, WaitForCompletion, Convert_Angle_to_Ticks, precisionMove)
            
            % precitionMove = 'precision' arm goes to full speed
            % precisionMove = 'speed' arm goes slowly in position
            
            % switch to not touch the grabber during moves
            if(obj.grabberOverride == 1)
                MaxServoIndex = 6;
            else
                MaxServoIndex = 7;
            end
            
            if(Convert_Angle_to_Ticks == 1)
                for i=1:MaxServoIndex
                    GoalPos(i) = GoalPos(i) * obj.AngleToTicks(i);
                end
            end
            
            % Hamming constant
            a0 = 0.64;
            
            IterCounter =0;
            
            DebugArray = zeros(7,50);
            DebugCounter = 1;
            
            StartPos = obj.ReadServoPos();
            
            % for servos with software slaving: switch the integral part of
            % the PID during the move off!
%             try
%                 dxl_addparam_result = groupSyncWriteAddParam(obj.group_i_gain, obj.DXL_ID(3), 10, obj.LEN_MX_I_GAIN);
%                 dxl_addparam_result = groupSyncWriteAddParam(obj.group_i_gain, obj.DXL_ID(9), 10, obj.LEN_MX_I_GAIN);
%                 groupSyncWriteTxPacket(obj.group_i_gain);
%                 dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
%                 groupSyncWriteClearParam(obj.group_i_gain);
%             catch
%                 
%             end
            if strcmp(precisionMove, 'precision')
                obj.SetPID('precision');
            else
                obj.SetPID('speed');
            end
            
            % Program of the goal position % ***************************************************
            for i=1:MaxServoIndex
                dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_pos, obj.DXL_ID(i), GoalPos(i), obj.LEN_MX_GOAL_POSITION);
                if dxl_addparam_result ~= true
                    fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                    dxl_error = fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                    return;
                else
                    dxl_error = 0;
                end
                % software slaving of the second ellbow servo
                if (i==3)
                    % look up the goal positin of servo 9 from the setpoint
                    % of servo 3
                    f = polyval(obj.p_servo, GoalPos(i));
                    % and set it as the goalpos for servo 9
                    dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_pos, obj.DXL_ID(9), f, obj.LEN_MX_GOAL_POSITION);
                    if dxl_addparam_result ~= true
                        fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                        dxl_error = fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                        return;
                    else
                        dxl_error = 0;
                    end
                end
            end
            % Syncwrite goal position
            groupSyncWriteTxPacket(obj.group_num_pos);
            dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
            if dxl_comm_result ~= obj.COMM_SUCCESS
                fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
            end
            % Clear syncwrite parameter storage
            groupSyncWriteClearParam(obj.group_num_pos);     
            
            if (WaitForCompletion == 1)
                while 1
                    IterCounter = IterCounter +1;   %Keep track if we are stuck
                    currentPos = obj.ReadServoPos();
                    dist = 0;
                    for i = 1:MaxServoIndex
                        dist = dist + abs(GoalPos(i) - currentPos(i));
                    end
                    %dist % DEBUG
                    
                    % if we reached the goal position, stop
                    if ~(dist > obj.DXL_MOVING_STATUS_THRESHOLD*6)
                        break;
                    end
                    if (IterCounter > 150)
                        for i = 1:MaxServoIndex
                            i
                            dist =  abs(GoalPos(i) - currentPos(i))
                        end
                        IterCounter = 0
                    end
                    
                    
                    
                    DebugCounter = DebugCounter + 1; %DEBUG remove
                    for i=1:MaxServoIndex
                        
%                         n0=1024;
%                         goal=4096;
%                         N = goal-n0
%                         clear Hamming_dx0;
%                         Hamming_dx0 = a0 - (1 - a0)*cos( 2* pi * (i-n0) / N);
%                         for i=1025:4096
%                         Hamming_dx0 = [Hamming_dx0, a0 - (1 - a0)*cos( 2* pi * (i-n0) / N)];
%                         end
%                         figure(1);
%                         plot(Hamming_dx0);
                        
                        n0 = StartPos(i);
                        n = currentPos(i) - n0;
                        N =  GoalPos(i) - n0;
                        Hamming_dx0 = a0 - (1 - a0)*cos( 2* pi * n / N);
                        
                        if strcmp(precisionMove, 'precision')
                            SpeedDivider = 2.5;
                        else
                            SpeedDivider = 1;
                        end;
                        
                        if (strcmp(obj.SERVO_TYPE{i}, 'MX-28'))
                            % the base servo omust run somewhat slower due
                            % to the high intertia of the arm
                            if (obj.DXL_ID(i) == 1)
                                MinSpeed = 20 / SpeedDivider;
                                speedScaling  = abs(StartPos(i) - GoalPos(i))/4096;
                                speed = max( floor(7* obj.DEFAULTMAXSPEED_MX28_Base*Hamming_dx0 * speedScaling) , MinSpeed);
                            else
                                MinSpeed = 30 / SpeedDivider;
                                speedScaling  = abs(StartPos(i) - GoalPos(i))/4096;
                                speed = max( floor(7* obj.DEFAULTMAXSPEED_MX28*Hamming_dx0 * speedScaling) , MinSpeed);
                            end
                        else if (strcmp(obj.SERVO_TYPE{i}, 'MX-64') )
                                speedScaling  = abs(StartPos(i) - GoalPos(i))/4096;
                                MinSpeed = 15 / SpeedDivider;
                                speed = max( floor(7* obj.DEFAULTMAXSPEED_MX64*Hamming_dx0 * speedScaling) , MinSpeed);
                            else if (strcmp(obj.SERVO_TYPE{i}, 'MX-106'))
                                    speedScaling  = abs(StartPos(i) - GoalPos(i))/4096;
                                    MinSpeed = 15 / SpeedDivider;
                                    speed = max( floor(7* obj.DEFAULTMAXSPEED_MX106*Hamming_dx0 * speedScaling) , MinSpeed);
                                else
                                    speedScaling  = abs(StartPos(i) - GoalPos(i))/1024;
                                    MinSpeed = 35 / SpeedDivider;
                                    speed = max( floor(7* obj.DEFAULTMAXSPEED_AX18*Hamming_dx0 * speedScaling) , MinSpeed);
                                end
                            end
                        end
                        if (isnan(speed) || (speed < 1.0))
                            speed = 0;
                        end
                        
                        DebugArray(i, DebugCounter) =speed;
                        
                        % set the new adapted speed to the comm payload
                        dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(i), speed, obj.LEN_MX_MOVING_SPEED);
                        if dxl_addparam_result ~= true
                            fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                            return;
                        end
                        % software slaving of the second ellbow servo #9
                        if (i==3)
                            % set the new adapted speed to the comm payload
                            dxl_addparam_result = groupSyncWriteAddParam(obj.group_num_speed, obj.DXL_ID(9), speed, obj.LEN_MX_MOVING_SPEED);
                            if dxl_addparam_result ~= true
                                fprintf('[ID:%03d] groupSyncWrite addparam failed', obj.DXL_ID(i));
                                return;
                            end
                        end
                    end
                    % Syncwrite the new speed update to the servos
                    groupSyncWriteTxPacket(obj.group_num_speed);
                    dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
                    if dxl_comm_result ~= obj.COMM_SUCCESS
                        fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
                    end
                    % Clear syncwrite parameter storage for speed
                    groupSyncWriteClearParam(obj.group_num_speed);
                    
                end
                
%                 plot(DebugArray(1,:));
%                 hold on;
%                 plot(DebugArray(2,:));
%                 plot(DebugArray(3,:));
%                 plot(DebugArray(4,:));
%                 plot(DebugArray(5,:));
%                 plot(DebugArray(6,:));
%                 hold off;
                
            end
            
            % at the end of the move we go in precision mode for maximal
            % convergence to the goal position (and to prepare potential
            % follow-up moves of higer precision
            obj.SetPID('precision');
            
%             % for servos with software slaving: switch the integral part of
%             % the PID during the move off!
%             try
%                 dxl_addparam_result = groupSyncWriteAddParam(obj.group_i_gain, obj.DXL_ID(3), 5, obj.LEN_MX_I_GAIN);
%                 dxl_addparam_result = groupSyncWriteAddParam(obj.group_i_gain, obj.DXL_ID(9), 5, obj.LEN_MX_I_GAIN);
%                 groupSyncWriteTxPacket(obj.group_i_gain);
%                 dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
%                 groupSyncWriteClearParam(obj.group_i_gain);
%             catch
%                 
%             end
            
        end       
        % ========================================== Read the position of all Servos ==========================================
        function myPos = ReadServoPos(obj)
            myPos = zeros(7,0);
            for i=1:7
                % Read Dynamixel#3 present position
                myPos(i) = read2ByteTxRx(obj.port_num, obj.PROTOCOL_VERSION, obj.DXL_ID(i), obj.ADDR_MX_PRESENT_POSITION);
                dxl_comm_result = getLastTxRxResult(obj.port_num, obj.PROTOCOL_VERSION);
                dxl_error = getLastRxPacketError(obj.port_num, obj.PROTOCOL_VERSION);
                if dxl_comm_result ~= obj.COMM_SUCCESS
                    fprintf('%s\n', getTxRxResult(obj.PROTOCOL_VERSION, dxl_comm_result));
                elseif dxl_error ~= 0
                    fprintf('%s\n', getRxPacketError(obj.PROTOCOL_VERSION, dxl_error));
                end
            end
        end

        
        
    end
end

