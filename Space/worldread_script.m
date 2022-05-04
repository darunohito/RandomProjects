% pkg load mapping
tic
close all

nNodes = 4; nTgts = 2; fCenter = 100e6; 
worldFileName = [pwd '\ETOPO1_Ice_g_geotiff\ETOPO1_Ice_g_geotiff.tif'];

locationWindow = [-107.34, 34.48; -106.27, 35.39]; % long/lat deg, ABQ area
tgtMinElevationDeg = 30; % deg from vertical
tgtRangeWindow= [5e3, 15e3]; % ([min, max] from plot center)

%% read file
if ~exist('bands') || ~strcmp(bands.name,worldFileName)
  [bands, info] = rasterread (worldFileName);
  bands.name = worldFileName;
end

[nodes, h] = generateNodes(bands,info,locationWindow,nNodes,'plot');
[tgts, h] = generateTargets(tgtMinElevationDeg,tgtRangeWindow,nodes.center,nTgts,'plot',h); 
radio = coopTRXparams(nodes, tgts);

% should I solve the analytical solutions for each radiator at each point in space?
% plot power density in free space, with superimposed beams?
% should I do the same work with FSPL, time delay, and a real signal/reflection?

% maybe I should focus on receive & autocorrelation first?



toc