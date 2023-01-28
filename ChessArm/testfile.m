MyProcessor = PointCloudProcessing(Xr2,Yr2,Zr2, 0);

MyProcessor.getValidIndex(0);

[MyProcessor.ptCloud, MyProcessor.loc] = MyProcessor.createPointCloud();
pcshow(MyProcessor.ptCloud);


[MyProcessor.labels,MyProcessor.numClusters] = MyProcessor.getClusters();

MyProcessor.colorClusters();

MyProcessor.coors = MyProcessor.getClusterCenter();

MyProcessor.fuseClusters();