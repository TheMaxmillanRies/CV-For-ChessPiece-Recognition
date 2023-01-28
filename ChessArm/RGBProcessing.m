classdef RGBProcessing < handle
    
    properties
        tform;
        
        cfS = 90;
        MyNet
        beforeImage;
        afterImage;
        
        WhitePiecesOnBoard;
        difference1;
        difference2;
        
        max1 = 0;
        max1Index = 0;
        max2 = 0;
        max2Index = 0;
        
        scrapAxis
        
    end
    
    methods
        function obj = RGBProcessing(scrapAxis)
            obj.scrapAxis = scrapAxis;
            obj.Initialize();
        end
        
        function Initialize(obj)
            Image = obj.LoadImage('ptCloud_RGB_calibration.mat');   % ToDo this needs to mcome with the constructor as an argument
            [imagePoints,boardSize,pairsUsed] = detectCheckerboardPoints(Image, 'MinCornerMetric', 0.55);
            rim = 0;
            fixedPoints = [obj.cfS+rim obj.cfS+rim; 7*obj.cfS+rim obj.cfS+rim; 7*obj.cfS+rim 7*obj.cfS+rim; obj.cfS+rim 7*obj.cfS+rim];
            movingPoints = [imagePoints(7,:); imagePoints(1,:); imagePoints(43,:); imagePoints(49,:)];
            a = zeros(4,1);
            for i = 1:4
                a(i) = movingPoints(i,1) * movingPoints(i,2);
            end
            [a, indexI] = sort(a);
            movingPoints  = [ movingPoints(indexI(1),:); movingPoints(indexI(2),:); movingPoints(indexI(4),:); movingPoints(indexI(3),:) ];
            obj.tform = fitgeotrans(movingPoints, fixedPoints, 'projective');
            
            load('ChessGoogleDeepLearningNet2.mat');
            obj.MyNet = net;
            
        end
        
        function UpdateBeforeMovePicture(obj, RGBimage)
            Image = imwarp(RGBimage, obj.tform, 'OutputView', imref2d([8*obj.cfS, 8*obj.cfS ]));
            obj.beforeImage = Image;    %rgb2gray(Image);
        end

        function UpdatePostMovePicture(obj, RGBimage)
            Image = imwarp(RGBimage, obj.tform, 'OutputView', imref2d([8*obj.cfS, 8*obj.cfS ]));
            obj.afterImage = Image; %rgb2gray(Image);
        end
        
        function subImg = ExtractSubimage(obj, RGBimage, x, y)
            cfS = obj.cfS;
            rim = 30;
            Image = imwarp(RGBimage, obj.tform, 'OutputView', imref2d([8*obj.cfS+2*rim, 8*obj.cfS+2*rim]));
            subImg = ( Image( (x-1)*cfS+1:x*cfS+2*rim, (y-1)*cfS+1:y*cfS+2*rim, :) );
            %imwrite(RGBimage,'testImage.png');
%             figure(1);
%             imshow(subImg);
            
        end
        
        
        function occupation = AnalyzeFieldOccupation(obj, MyRGBImage)
            cfS = obj.cfS;
            occupation = zeros(8,8);
            for x = 1:8
                for y = 1:8  
                    SubImage = obj.ExtractSubimage(MyRGBImage, x, y);
                    
                    SubImage(1:30,:,:) = 128;
                    SubImage(end-30:end,:,:) = 128;
                    SubImage(:,1:30,:) = 128;
                    SubImage(:,end-30:end,:) = 128;
                    
                    [YPred,scores] = classify(obj.MyNet, SubImage);
                    
                    if (YPred == 'black')
                        occupation(x,y) = 1;
                    end
                    if (YPred == 'white')
                        occupation(x,y) = 2;
                        figure(1);
                        imshow(SubImage);
                        a=5;
                    end
                    if (YPred == 'EmptyField')
                        occupation(x,y) = 0;
                    end 
                end
            end
            occupation
        end
        
        
        function ProcessImages(obj)
            
            % compensate for a changing luminosity by a histogram
            % correction
            %J = imhistmatch(obj.beforeImage,obj.afterImage);
            
            [BW,maskedRGBImageA] = FilterPieces(obj.afterImage);
            [BW,maskedRGBImageB] = FilterPieces(obj.beforeImage);
            
          
%             global testimg
%             testimg = obj.afterImage;
% %             
%             figure(20);
%             imshow(maskedRGBImageA);
%             figure(21);
%             imshow(maskedRGBImageB);      
%             
%             figure(22);
%             imshow(obj.afterImage);
%             figure(23);
%             imshow(obj.beforeImage);
%             
%             figure(24);
             hsv_maskedRGBImageA = rgb2hsv(maskedRGBImageA);
%             imshow(hsv_maskedRGBImageA);
%             figure(25);
             hsv_maskedRGBImageB = rgb2hsv(maskedRGBImageB);
%             imshow(hsv_maskedRGBImageB);
            
            difference1 = abs(hsv_maskedRGBImageA(:,:,3) - hsv_maskedRGBImageB(:,:,3));
            difference2 = abs(hsv_maskedRGBImageB(:,:,3) - hsv_maskedRGBImageA(:,:,3));
            
            
%             difference1 = abs(rgb2gray(maskedRGBImageA) - rgb2gray(maskedRGBImageB));
%             difference2 = abs(rgb2gray(maskedRGBImageB) - rgb2gray(maskedRGBImageA));
%           figure('doublebuffer','on','Visible','Off');

 
            imshow(difference1,'Parent', obj.scrapAxis);
%            imshow(difference2);

            obj.WhitePiecesOnBoard = zeros(8,8);
            for x = 1:8
                for y = 1:8
                    offset = 0;%(y-4.5)*4;
                    
                    %figure(5)
                    h = drawellipse('Parent', obj.scrapAxis, 'Center',[x*obj.cfS-obj.cfS/2 y*obj.cfS-obj.cfS/2+offset],'SemiAxes',[obj.cfS/3 obj.cfS/3], 'RotationAngle',0 ,'StripeColor','m');
                    mask = createMask(h);
                    obj.difference1(x,y) = sum(difference1(mask));
                    msg = num2str(x) + "/"+num2str(y)+ "/"+num2str(obj.difference1(x,y));
                    text(x*obj.cfS-obj.cfS/2-10, y*obj.cfS, msg, 'color', 'r');                   
%                     figure(6)
%                     h = drawellipse('Center',[x*obj.cfS-obj.cfS/2 y*obj.cfS-obj.cfS/2+offset],'SemiAxes',[obj.cfS/3 obj.cfS/3], 'RotationAngle',0 ,'StripeColor','m');
%                     mask = createMask(h);
%                     obj.difference2(x,y) = sum(difference2(mask));
%                     msg = num2str(x) + "/"+num2str(y)+ "/"+num2str(obj.difference2(x,y));
%                     text(x*obj.cfS-obj.cfS/2-10, y*obj.cfS, msg, 'color', 'g');
                end
            end  
            % largest value of change
            maxVal = max(obj.difference1(:));
            index_max = find(obj.difference1 == maxVal);
            % second largest
            xtmp = reshape(obj.difference1,1,64);
            secondMaxVal =  max(xtmp(xtmp<max(xtmp)));
            index_smax = find(obj.difference1 == secondMaxVal);
            obj.WhitePiecesOnBoard(index_max) = 1;
            obj.WhitePiecesOnBoard(index_smax) = 1;
            
        end
        
        function getMax(obj)
            for i = 1:8
                for j = 1:8
                    if(obj.MotionOnBoard(i,j) > obj.max1)
                        obj.max2 = obj.max1;
                        obj.max2Index = obj.max1Index;
                        obj.max1 = obj.MotionOnBoard(i,j);
                        obj.max1Index = [i,j];
                    elseif(obj.MotionOnBoard(i,j) > obj.max2)
                        obj.max2 = obj.MotionOnBoard(i,j);
                        obj.max2Index = [i,j];
                    end
                end
            end
        end
        
        function Image = FitCropAndBW(obj, Image)
            Image = imwarp(Image, obj.tform, 'OutputView', imref2d(size(Image)));
            Image = imcrop(Image, [0 0 398 398]);
            Image = rgb2gray(Image);
        end
        
        function Image = LoadImage(obj, String)
            Struct = load(String, 'Image');
            Image = Struct.Image;
        end
    end
end

