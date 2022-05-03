% pkg load mapping
tic
close all
nNodes = 1; nTgts = 1;
worldFileName = [pwd '\ETOPO1_Ice_c_geotiff\ETOPO1_Ice_c_geotiff.tif'];

locationWindow = [-107.34, 34.48; -106.27, 35.39]; % long/lat deg, ABQ area
tgtMinElevationDeg = 30; % deg from vertical
tgtRangeWindow= [5e3, 15e3]; % ([min, max] from plot center)
pointingError = 5; % degrees of average TX pointing error

%% read file
if ~exist('bands') || ~strcmp(bands.name,worldFileName)
  [bands, info] = rasterread (worldFileName);
  bands.name = worldFileName;
end

[nodes, h] = generateNodes(bands,info,locationWindow,nNodes,'plot');
[tgts, h] = generateTargets(tgtMinElevationDeg,tgtRangeWindow,nodes.center,nTgts,'plot',h); 

nodes.aerTargets = zeros(nNodes,nTgts,3);
for ii = 1:nNodes
  [nodes.aerTargets(ii,:,1),nodes.aerTargets(ii,:,2),nodes.aerTargets(ii,:,3)] = ...
    geodetic2aer(tgts.geodetic(:,1),tgts.geodetic(:,2),tgts.geodetic(:,3),...
    nodes.geodetic(ii,1),nodes.geodetic(ii,2),nodes.geodetic(ii,3),'wgs84','degrees');
end


  
toc