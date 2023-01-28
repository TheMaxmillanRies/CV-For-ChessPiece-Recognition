classdef PointCloudAnalysis < handle
    % Class used to analyze and process a given pointcloud
    
    
    properties
        X; Y; Z; % Point Cloud Data
        
        point_cloud; % Point Cloud MatLab object
        
        board_middle; %Array with XY median values
    end
    
    methods
        
        % Constructor of the Point Cloud Analysis Class
        function obj = PointCloudAnalysis(data_type, data)
            
            if data_type == "raw_data"
                obj.AssignRawData(data(:,1), data(:,2), data(:,3));
                obj.point_cloud = obj.CreatePointCloud(obj.X, obj.Y, obj.Z);
            end
            
            if data_type == "point_cloud"
                obj.AssignPointCloud(data);
                obj.GetPointCloudData();
            end
            
        end
        
        % Assigns input to XYZ data
        function AssignRawData(obj, X, Y, Z)
            % Store given coordinates in class properties
            obj.X = X;
            obj.Y = Y;
            obj.Z = Z;
        end
        
        % Assigns input to point cloud
        function AssignPointCloud(obj, input_point_cloud)
            obj.point_cloud = input_point_cloud;
        end
        
        % Creates point cloud based on object's current XYZ data
        function point_cloud = CreatePointCloud(obj, X, Y, Z)
            point_cloud = pointCloud([X, Y, Z]);
        end
        
        % Displays Point Cloud on desired figure
        function PlotPointCloud(obj, point_cloud, figureNumber)
            figure(figureNumber); % Set figure number

            % Display the grid of the chessboard
            data = point_cloud.Location;
            for row = 0.148:-0.037:-0.148
                for column = -0.148:0.005:0.148
                    data = vertcat(data, [column, row, 0.3925]);
                end
            end
            
            for column = -0.148:0.037:0.148
                for row = 0.148:-0.005:-0.148
                    data = vertcat(data, [column, row, 0.3925]);
                end
            end
            
            point_cloud = obj.CreatePointCloud(data(:,1), data(:,2), data(:,3));
            
            pcshow(point_cloud); % Display Point Cloud
            
            % Set axis labels
            xlabel('X');
            ylabel('Y');
            zlabel('Z');
        end
        
        % Plot current class point cloud
        function PlotCurrentPointCloud(obj, figureNumber)
            obj.PlotPointCloud(obj.point_cloud, figureNumber);
        end
        
        % Update XYZ to current point cloud data
        function GetPointCloudData(obj)
            % Obtain matrix containing pointcloud X Y and Z coordinates
            data_matrix = obj.point_cloud.Location;
            
            % Split matrix into 3 respective component vectors
            obj.X = data_matrix(:,1);
            obj.Y = data_matrix(:,2);
            obj.Z = data_matrix(:,3);
        end
        
        % Clip point cloud XYZ based on given boundaries
        function [X, Y, Z] = ClipPointCloud(obj, X, Y, Z, x_bounds, y_bounds, z_bounds)
            % Get index of objects which fullfill given condition
            clipIndex = find((X < x_bounds(1) & X > x_bounds(2)) & ...
                (Y < y_bounds(1) & Y > y_bounds(2)) & ...
                (Z < z_bounds(1) & Z > z_bounds(2)));
            
            % Update XYZ to clipped values
            X = X(clipIndex);
            Y = Y(clipIndex);
            Z = Z(clipIndex);
        end
        
        % Use calibration file to get middle of the board and center the data
        function Calibrate(obj, name, height)
            % Load calibration pointcloud
            calibration_point_cloud = load(name);
            new_calibration_data = calibration_point_cloud.point_cloud.Location;
            
            % Get Center Piece XYZ information
            [calibration_data.X, calibration_data.Y, calibration_data.Z] = ...
                obj.ClipPointCloud(new_calibration_data(:,1), new_calibration_data(:,2), new_calibration_data(:,3), [0.1, 0], [0.05, -0.05], [0.4, 0.3]);
            
            % Get Median of the pointcloud -> Center of the board
            obj.board_middle.X = median(calibration_data.X);
            obj.board_middle.Y = median(calibration_data.Y);
            
            % Center data
            obj.X = obj.X - obj.board_middle.X;
            obj.Y = obj.Y - obj.board_middle.Y;
            
            % Clip pointcloud using size of board and center information and update point cloud
            [obj.X, obj.Y, obj.Z] = obj.ClipPointCloud(obj.X, obj.Y, obj.Z, [0.148, -0.148], [0.148, -0.148], [height, 0.3]);
            
            obj.point_cloud = obj.CreatePointCloud(obj.X, obj.Y, obj.Z);
        end
        
        % Process data using clustering techniques
        function board_state = ClusterProcessing(obj, min_distance, iteration_count, slice_ratio, min_distance_increase)
            
            % min_distance = 0.003; %0.0075;
            final_data = [obj.X, obj.Y, obj.Z];
            cluster_center_list = [];
                        
            for iteration = 1:iteration_count
                sizeZ = size(final_data(:,3));
                newZ = zeros(sizeZ(1), 1);
                
                new_pc = pointCloud([final_data(:,1), final_data(:,2), newZ]);
                %new_pc = pointCloud([final_data(:,1), final_data(:,2), final_data(:,3)]);
                  %obj.PlotPointCloud(new_pc, iteration);
                [labels, numClusters] = pcsegdist(new_pc, min_distance);
%                 if numClusters ~= 0 && iteration == 5
%                      obj.ColorClusters(new_pc, labels, numClusters, 2);
%                 end
                
                cluster_center_list = zeros(numClusters, 3);
                new_data = [0, 0, 0];
                
                for i = 1:numClusters
                    % Find data belonging to cluster
                    index  = find(labels == i);
                    newX = final_data(index, 1);
                    newY = final_data(index, 2);
                    newZ = final_data(index, 3);
                    
                    data = [newX, newY, newZ];
                    
                    [~,idx] = sort(data(:,3)); % sort just by the height column
                    data = data(idx,:);   % sort the whole matrix using the sort indices

                    d_size = size(data);
                    
                    % Keep Portion of data
                    data = data(1:round(d_size(1)/slice_ratio), :);
                    new_data = [new_data; data];
                    
                    % Find center of mass of piece and insert into array
                    cluster_center = mean(data);
                    cluster_center_list(i,:) = cluster_center;
                    
%                     % Print Cluster Centers on a plot
%                     figure(3)
%                     hold on
%                     plot3(cluster_center_list(i,1), cluster_center_list(i,2), cluster_center_list(i,3), 'O','LineWidth',3);
%                     hold off

                end
                new_data(1,:) = [];
                final_data = new_data;
                min_distance = min_distance + min_distance_increase;
            end

            %Map centers to grid and interpolate which squares a piece is on
            
            board_state = "";
            
            % Outer Loop: Rows. Inner loop: Columns.
            for column = -0.148:0.037:0.111
                for row = -0.148:0.037:0.111
                    
                    [tmpX, tmpY, tmpZ] = obj.ClipPointCloud(cluster_center_list(:,1), cluster_center_list(:,2), cluster_center_list(:,3), [row+0.037, row],...
                        [column+0.037, column],...
                        [0.4, 0.3]);
                    
                    % Get number of data points
                    d_size = size(tmpX);
                    
                    % Append to string if a piece is there or not
                    if d_size(1) > 0
                        board_state = board_state + "1";
                    else
                        board_state = board_state + "0";
                    end
                end
                board_state = board_state + "/";
            end
            % DEBUG: Display final string
            %disp(board_state);
        end
        
        % Colors Clusters
        function ColorClusters(obj, point_cloud, labels, numClusters, figureNumber)
            labelColorIndex = labels+1;
            
            % Currently Plot on figure 2. To be changed
            figure(figureNumber);
            pcshow(point_cloud.Location, labelColorIndex);
            
            % Change background to white. Black cluster invisible on black
            % background and label axis
            set(gca,'color','w');
            xlabel('X');
            ylabel('Y');
            zlabel('Z');
            
            % Make colormap using number of clusters
            colormap([hsv(numClusters+1);[0 0 0]]);
        end
        
        
        
        % Process the data with a "Rolling Mask"
        function board_state = SegmentationProcessing(obj, shrink_offset, threshold)
            
            % Board string and offset
            board_state = "";
            
            % Outer Loop: Rows. Inner loop: Columns.
            for column = -0.148:0.037:0.111
                for row = -0.148:0.037:0.111
                    
                    % Clip data
                    [tmpX, tmpY, tmpZ] = obj.ClipPointCloud(obj.X, obj.Y, obj.Z, [row+0.037-shrink_offset, row+shrink_offset],...
                        [column-shrink_offset+0.037, column+shrink_offset],...
                        [0.4, 0.3]);
                    
                    % Get number of data points
                    d_size = size(tmpX);
                    
                    % Append to string if a piece is there or not
                    if d_size(1) > threshold
                        board_state = board_state + "1";
                                            else
                        board_state = board_state + "0";
                    end
                end
                board_state = board_state + "/";
            end
            % DEBUG: Display final string
            %disp(board_state);
        end
        
    end
end