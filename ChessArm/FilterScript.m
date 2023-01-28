
newDir = "G:\ChessDeepLearning2\EmptyField\";
oldir = "G:\ChessDeepLearning\EmptyField\";

figure(1);

oldname = oldir + "*.png";
files = dir(oldname);
for i=1:length(files)
    name =  string(oldir +  files(i).name);
    MyImage = imread(name);
    [BW,maskedRGBImage] = ColorSaturationFilter4(MyImage);
    se = offsetstrel('ball',3,3);
    %se = strel('cube',3)
    J = imerode(maskedRGBImage,se);
    mask = find(J==0);  
    maskedRGBImage(mask) = 0;
    
    newname = string(newDir + files(i).name);
    imwrite(maskedRGBImage, newname);
    figure(1);
    subplot(1,2,1), imshow(MyImage);
    subplot(1,2,2), imshow(maskedRGBImage);
end