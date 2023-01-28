classdef PointCloudProcessing < handle
    %Class which processes a given point cloud and forward kinematics
    %matrix to obtain the individual clusters representing chess pieces.
    
    properties
        
        %forward kinematics for clipping purposes
        fkine; %CURRENTLY HARDCODED/UNUSED
        
        %what does name stand for?
        loc;
        
        %pointCloud
        ptCloud;
        
        %minimum distance for cluster rendering. Default 0.0075
        minDistance = 0.006;
        
        %number of clusters
        numClusters;
        
        %cluster labels
        labels;
        
        %Cluster coordinates
        coors;
        
        %Cluster coordinates with offset corrections
        corrected_coors;
            
        %Chessboard Distance to mirror image
        mirrorValue = 0.28;
        
        % callibration value to go from camera coordinates to chess board
        % coordinates with an affine 3D transformation
        offset = [0,0,0];
    end
    
    methods
        function obj = PointCloudProcessing(X, Y, Z)
            obj.loc = [X(:), Y(:), Z(:)];
            obj.ptCloud = pointCloud(obj.loc);
        end
        
        function obj = CalibratePointCloudProcessing(obj, X, Y, Z)
            % calibrate with the initial measurement of one pawn right in the
            % middle of the board
              % this should isolate the center pawn
                %indexClipped = find((Y<0.2) & (Y>-0.2) &(X<0.20) & (X>-0.175) & (Z<0.40)& (Z>0.20));
                indexClipped = find((Y<0.1) & (Y>-0.1) &(X<0.10) & (X>-0.10) & (Z<0.395)& (Z>0.30));
                Xc = X(indexClipped);
                Yc = Y(indexClipped);
                Zc = Z(indexClipped);
              % calculate the median location of the pawn and set this as our
              % affine 3D offset between camer and board.
                Xc_median = median(Xc);
                Yc_median = median(Yc);
                Zc_median = median(Zc);
            obj.offset = [Xc_median, Yc_median, Zc_median];
        end
        
        %Printing function which displays the current pointCloud
        function DisplayRawPointData(obj, figureNumber)
            figure(figureNumber);
            plot3(obj.loc(:,1),obj.loc(:,2),obj.loc(:,3),'.');
            xlabel('X');
            ylabel('Y');
            zlabel('Z');
        end
        
        function range = getRange(obj, fkine)
            range = 0; %DELETE ME
        end
        
        % clip the ground plane to leave only data at the height of the
        % board pieces. This requires the calibration step completed
        function obj = getValidIndex(obj)
            %indexClipped = find(( obj.loc(:,2)<0.2) & (obj.loc(:,2)>-0.2) &(obj.loc(:,1)<0.175) & (obj.loc(:,1)>-0.175)& (obj.loc(:,3)<obj.offset(3)+0.02)& (obj.loc(:,3)>0.20));
            % clip the data with reference of the calibration point
            indexClipped = find( (obj.loc(:,2)< (obj.offset(2) + 0.15)) & (obj.loc(:,2)>(obj.offset(2) - 0.15)) & (obj.loc(:,1) < (obj.offset(1) + 0.15)) & (obj.loc(:,1)>(obj.offset(1) - 0.15))& (obj.loc(:,3)<obj.offset(3)+0.02)& (obj.loc(:,3)>0.20));
            
            % decimate the point locations
            obj.loc = obj.loc( indexClipped(:,1),:);
            % update the point cloud object accordingly
            obj.ptCloud = pointCloud(obj.loc);
        end
        
        function filterNoise(obj)
            % decimate outliers and single points of the point cloud
            obj.ptCloud = pcdenoise(obj.ptCloud);
        end
        
        function getClusters(obj)
             % segments a point cloud into clusters, with a minimum Euclidean distance of minDistance between points from different clusters. 
            [labels,numClusters] = pcsegdist(obj.ptCloud,obj.minDistance);
            obj.labels = labels;
            obj.numClusters = numClusters;
        end
        
        function colorClusters(obj, fignum)
            labelColorIndex = obj.labels+1;
            figure(fignum);
            pcshow(obj.ptCloud.Location,labelColorIndex);
            colormap([hsv(obj.numClusters+1);[0 0 0]]);
            title('Point Cloud Clusters');
        end
        
        function DisplayPointCloud(obj, fignum)
            figure(fignum);
            pcshow(obj.ptCloud.Location);
            title('Point Cloud Clusters');
        end
        
        function coors = calcClusterCenter(obj)
            for i=1:obj.numClusters
                index = find(obj.labels == i);
                clusterCoors = obj.loc(index,:);
                obj.coors(i,:) = mean(clusterCoors);
                obj.corrected_coors(i,:) = obj.coors(i,:) - obj.offset;
            end
        end
        
        function PrintClusterCenter(obj, corrCords, numfig)
            figure(2);
            for i = 1:obj.numClusters
                hold on;
                if (corrCords == 1)
                    plot3(obj.coors(i,1), obj.coors(i,2), obj.coors(i,3), 'O','LineWidth',3);
                else
                    plot3(obj.corrected_coors(i,1), obj.corrected_coors(i,2), obj.corrected_coors(i,3), 'O','LineWidth',3);
                end
                hold off;
            end
        end
        
        function fuseClusters(obj)
            for i=2:obj.numClusters
                for j = i:obj.numClusters
                    %if (i ~= j)
                        %calculate the distance between the two clusters
                        dis = sqrt( (obj.coors(i,1) - obj.coors(j,1))^2 + (obj.coors(i,2) - obj.coors(j,2))^2);
                        %fuse clusters, which are blow each other
                        if (dis<0.021) %default 0.02
                            index = find(obj.labels == j);
                            obj.labels(index) = i;
                        end
                    %end
                end
            end
            counter = 1;
            dummy_label = zeros(numel(obj.labels),1);
            for i=1:obj.numClusters
                index = find(obj.labels == i);
                if ( numel(index) > 1)
                    dummy_label(index) = counter;
                    counter=counter + 1;
                end
            end
            obj.labels = dummy_label;
            obj.numClusters = counter-1;
        end
        
        % This function does the heavy work for conditioning
        % 1st step: all clusters, which are in x-y too large are split with
        % a kmeans clustering in two subclusters
        % 2nd step: a corresponding new list of locs, numCluster, and all class variables is established
        % 3rd step: all clusters, which are vertically too close, are fused
        % in the same cluster
        % 4th step: This gets represted
        function ClusterConditioning(obj, numIter, eval)
            % iterate the cluster conditioning
            for clCounter = 1:numIter
               % 1st step: split too large clusters into subclusters
                labels = obj.labels;
                numClusters = obj.numClusters;
                NewNumClusters = 1; % new ordered number of total clusters
                nloc = zeros(1,3);  % new ordered point location list
                nlabels = [0];      % new corresponding point list
                       
                for i = 1:numClusters
                    index = find(labels == i);
                    % calculate the x-y extent of the cluster
                    cl = obj.loc(index,:);
                    sizeX = abs(max(cl(:,1))-min(cl(:,1)));
                    sizeY = abs(max(cl(:,2))-min(cl(:,2)));
                    
                    % criteria for too large clusters for split is applied
                    if ( (sizeX > (eval*0.037)) || (sizeY > (eval*0.037)))
                        % cluster too big, so we use kmeans clustering to
                        % subdivide it
                        Data2D = [cl(:,1), cl(:,2)];
                        Data3D = [cl(:,1), cl(:,2), cl(:,3)];
                        [idx,C] = kmeans(Data2D,2);
 
                        % add the first new subcluster to our new data list
                        new_index = find(idx == 1);
                        nloc = [nloc; cl(new_index,:)];
                        nlabels = [nlabels, ones(1, numel(new_index))*NewNumClusters];
                        NewNumClusters = NewNumClusters + 1;
                        % and add the second new subcluster
                        new_index = find(idx == 2);
                        nloc = [nloc; cl(new_index,:)];
                        nlabels = [nlabels, ones(1, numel(new_index))*NewNumClusters];
                        NewNumClusters = NewNumClusters + 1;
                    else
                        % the cluster checks out (i.e. sis small), so we simply concatinate it with the output data
                        nloc = [nloc; cl];
                        nlabels = [nlabels, ones(1,numel(index))*NewNumClusters];
                        NewNumClusters = NewNumClusters + 1;
                    end
                    
                end
                % clip first elements
                nloc = nloc(2:end,:);
                nlabels = nlabels(2:end);
                
                %write the data back into the class variables
                obj.loc = nloc;
                obj.labels = nlabels;
                obj.numClusters = NewNumClusters;
                % update the point cloud object
                obj.ptCloud = pointCloud(obj.loc);
                    
                % 2nd step of the iteration: vertical fusion of the clusters
                obj.calcClusterCenter();
                obj.fuseClusters();
            end
            
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
        
        
    end
end

