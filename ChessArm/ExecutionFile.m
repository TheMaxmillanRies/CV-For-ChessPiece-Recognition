% load("rnbqkbnr.pppppppp.8.8.8.8.PPPPPPPP.RNBQKBNR - Medium.mat");
% 
% point_cloud_processor = PointCloudAnalysis("point_cloud", point_cloud);
% point_cloud_processor.Calibrate("D:\MatLab Projects\Data\Calibration.mat");
% point_cloud_processor.PlotCurrentPointCloud(3);

% disp("Segmentation Result");
% seg_state = point_cloud_processor.SegmentationProcessing(0.00,0)

% disp("Clustering Result");
% cluster_state = point_cloud_processor.ClusterProcessing(0.003, 5, 1.5, 0.0)
% 
% disp("Ground Truth")
% ground_truth = ConvertGroundTruth(strrep('1n2rBk1.1RP2p1b.3P1PP1.1K5p.3p1rPQ.p1pBPpPn.N4Pp1.1N2b3 - Hard.mat','.','/'))


% for i = 1:200
%     figure(3);
%     hold on
%     plot((roc(i,4)/(roc(i,4) + roc(i,3))), roc(i,2)/(roc(i,2) + roc(i,5)),'.');
%     hold off
%     
%         if (roc(i,4)/(roc(i,4) + roc(i,3))) > 0.02137 && roc(i,2)/(roc(i,2) + roc(i,5)) > 0.9673
%             disp([i, (roc(i,4)/(roc(i,4) + roc(i,3))), roc(i,2)/(roc(i,2) + roc(i,5))]);
%         end
%     
% end
% xlabel("False Positive Rate");
% ylabel("True Positive Rate");


myDir = uigetdir;
myFiles = dir(fullfile(myDir,'*.mat'));
loaded_pc = load(fullfile(myDir, "Calibration.mat"));

point_cloud_processor = PointCloudAnalysis("point_cloud", loaded_pc.point_cloud);
point_cloud_processor.Calibrate(fullfile(myDir, "Calibration.mat"), 0.4);

% cluster_success = 0;
% segmentation_success = 0;

% array = [];

% [shrink_offset, TP, TN, FP, FN]
roc = [0, 0, 0, 0, 0, 0, 0];


for slice_value = 0.4:-0.0025:0.375
    TP = 0;
    TN = 0;
    FP = 0;
    FN = 0;
    
    for index = 1:length(myFiles)
        baseFileName = myFiles(index).name;
        fullFileName = fullfile(myDir, baseFileName);
        if(baseFileName == "Calibration.mat")
            continue;
        end
        
        baseFileName = strrep(baseFileName,'.','/');
        ground_truth = ConvertGroundTruth(baseFileName);
        %    disp("Ground Truth");
        %    disp(ground_truth);
        
        loaded_pc = load(fullFileName);
        point_cloud_processor.AssignPointCloud(loaded_pc.point_cloud);
        point_cloud_processor.AssignRawData(loaded_pc.point_cloud.Location(:,1), loaded_pc.point_cloud.Location(:,2), loaded_pc.point_cloud.Location(:,3));
        point_cloud_processor.Calibrate(fullfile(myDir, "Calibration.mat"), slice_value);
        
        %    disp("Segmentation Result");
        %         state = point_cloud_processor.SegmentationProcessing(0.009, threshold);
        %    disp(state);
        %     segmentation_success = segmentation_success + bool;
        % disp(bool);
        %     disp("Clustering Result");
        %state = point_cloud_processor.ClusterProcessing(0.003, 5, 1.5, 0.00175);
        state = point_cloud_processor.ClusterProcessing(0.006, 0, 1.5, 0.00175);
        %     disp(cluster_state);
        % cluster_success = cluster_success + bool;
        % disp(bool);
        bool = CompareStrings(ground_truth, state);
        
        bool = 1;
        state = convertStringsToChars(state);
        
        for char = 1:length(ground_truth)
            if ground_truth(char) == '1'&& state(char) == '1'
                TP = TP + 1;
                continue;
            end
            if ground_truth(char) == '0'&& state(char) == '0'
                TN = TN + 1;
                continue;
            end
            if ground_truth(char) == '1'&& state(char) == '0'
                FN = FN + 1;
                bool = 0;
                continue;
            end
            if ground_truth(char) == '0'&& state(char) == '1'
                FP = FP + 1;
                bool = 0;
                continue;
            end
        end
        
        
        %    disp("------------------------------------------------------");
        
        %     if bool == 0
        %         array = [array, baseFileName];
        %     end
        
    end
    roc = [roc; [0.003, TP, TN, FP, FN, 5, slice_value]];
end
xlabel("False Positive Rate");
ylabel("True Positive Rate");

disp("TP:" + TP);
disp("TN:" + TN);
disp("FP:" + FP);
disp("FN:" + FN);

function bool = CompareStrings(ground_truth, test_case)
bool = 1;
test_case = convertStringsToChars(test_case);
for index = 1:length(ground_truth)
    if ground_truth(index) ~= test_case(index)
        bool = 0;
        break
    end
end
end

function ground_truth = ConvertGroundTruth(ground_truth)
k = strfind(ground_truth,' ');
ground_truth = ground_truth(1:k-1);

ground_truth = strrep(ground_truth,'1','0');
ground_truth = strrep(ground_truth,'2','00');
ground_truth = strrep(ground_truth,'3','000');
ground_truth = strrep(ground_truth,'4','0000');
ground_truth = strrep(ground_truth,'5','00000');
ground_truth = strrep(ground_truth,'6','000000');
ground_truth = strrep(ground_truth,'7','0000000');
ground_truth = strrep(ground_truth,'8','00000000');

for index = 1:length(ground_truth)
    if ground_truth(index) ~= '0' && ground_truth(index) ~= '/'
        ground_truth(index) = '1';
    end
end
end


