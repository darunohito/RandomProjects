% pkg load mapping
clear
nNodes = 20; 

worldFileName = [pwd '\ETOPO1_Ice_c_geotiff\ETOPO1_Ice_c_geotiff.tif'];
[bands, info] = rasterread (worldFileName);


%% clip and plot
loc = [-107.34, 34.48; -106.27, 35.39]; % ABQ area
[cbands, cinfo] = rasterclip(bands, info, loc);
cbands.min = min(min(cbands.data));
cbands.max = max(max(cbands.data));
cmap = colormap;
figure(1); rasterdraw(cbands,cinfo);

cbands.x = linspace(cbands.bbox(1,1),cbands.bbox(2,1),size(cbands.data,2));
cbands.y = linspace(cbands.bbox(1,2),cbands.bbox(2,2),size(cbands.data,1));
nodes.x = randi(size(cbands.data,2),nNodes,1);
nodes.y = randi(size(cbands.data,1),nNodes,1);
nodes.z = cbands.data(sub2ind(size(cbands.data),nodes.y,nodes.x));

figure(2); mesh(cbands.x,cbands.y,cbands.data);
hold on; scatter3(cbands.x(nodes.x),cbands.y(nodes.y),nodes.z,'filled');
hold off;
zlabel('Altitude [m]')