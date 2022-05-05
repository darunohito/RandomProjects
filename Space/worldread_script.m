% pkg load mapping
tic
close all

c = 299792458;
nNodes = 4; nTgts = 2; fCenter = 100e6; 
ROI = 1000; %radial meters around radiation pattern main lobes and target
azimuthSteps = 16;
elevationSteps = 16;
N = 25; simRange = 5;

function rho = genericPattern(theta)
  rho = abs(sinc(theta));
endfunction

function [a] = fspl(r, lamdba)
  a = 20*log10(((4*pi)*r)/lamdba);
end

function pLog = lin2log(pLin)
  pLog = 10*log10(pLin);
endfunction

function pLin = log2lin(pLog)
  pLin = 10.^(pLog/10);
endfunction


worldFileName = [pwd '\ETOPO1_Ice_c_geotiff\ETOPO1_Ice_c_geotiff.tif'];

powerWindow = [100 1500]; % Watts, power from TX
locationWindow = [-107.34, 34.48; -106.27, 35.39]; % long/lat deg, ABQ area
tgtMinElevationDeg = 30; % deg from vertical
tgtRangeWindow= [5e3, 15e3]; % ([min, max] from plot center)

%% read file
if ~exist('bands') || ~strcmp(bands.name,worldFileName)
  [bands, info] = rasterread (worldFileName);
  bands.name = worldFileName;
end

clear nodes, tgts;
[nodes, h] = generateNodes(bands,info,powerWindow,locationWindow,nNodes);
[tgts, h] = generateTargets(tgtMinElevationDeg,tgtRangeWindow,nodes.center,nTgts); 
radio = coopTRXparams(nodes, tgts);


##mesh.azi = linspace(0,360*(1-1/azimuthSteps),azimuthSteps);
##mesh.ele = linspace(90*(1-1/elevationSteps),0,elevationSteps);
##mesh.searchPattern = [repmat(mesh.azi,elevationSteps,1)' repmat(mesh.ele,azimuthSteps,1)];
##mesh.search = zeros(nNodes,elevationSteps,azimuthSteps);


##mesh.geodetic = linspace([nodes.lat(1) nodes.long(1) min(nodes.geodetic(:,3))],...
##                         [nodes.lat(end) nodes.long(end) max(nodes.geodetic(:,3))],N);
%for ii = 1:nNodes
clear mesh


for ii = 1:1
  [lat0, lon0, alt0] = enu2geodetic(-simRange/2,-simRange/2,-simRange/2,nodes.geodetic(ii,1),nodes.geodetic(ii,2),nodes.geodetic(ii,3),'wgs84','degrees');
  [lat1, lon1, alt1] = enu2geodetic(simRange/2,simRange/2,simRange/2,nodes.geodetic(ii,1),nodes.geodetic(ii,2),nodes.geodetic(ii,3),'wgs84','degrees');
  mesh.geodetic(:,(ii-1)*N+1:ii*N) = linspace([lat0, lon0, alt0], [lat1, lon1, alt1],N);
endfor


mesh.geodetic = permute(repmat(mesh.geodetic,1,1,N,N),[2 3 4 1]);
lambda = c / fCenter;

[mesh.aer(1,:,:,:,:),mesh.aer(2,:,:,:,:),mesh.aer(3,:,:,:,:)] = geodetic2aer(repmat(mesh.geodetic(:,:,:,1),1,1,1,nNodes), repmat(mesh.geodetic(:,:,:,2),1,1,1,nNodes), repmat(mesh.geodetic(:,:,:,3),1,1,1,nNodes), permute(repmat(nodes.geodetic(:,1),1,N,N,N),[2 3 4 1]),permute(repmat(nodes.geodetic(:,2),1,N,N,N),[2 3 4 1]),permute(repmat(nodes.geodetic(:,3),1,N,N,N),[2 3 4 1]),'wgs84','degrees');

[mesh.enu(1,:,:,:,:),mesh.enu(2,:,:,:,:),mesh.enu(3,:,:,:,:)] = aer2enu(mesh.aer(1,:,:,:,:),mesh.aer(2,:,:,:,:),mesh.aer(3,:,:,:,:)); % m, cartesian displacement from each node to each mesh point

mesh.enuNormZero = mesh.enu ./ repmat(mesh.aer(3,:,:,:,:),3,1,1,1,1);
radio.enuNormZero = repmat(radio.enuNormZero,1,1,1,N,N,N);
radio.enuNormZero = permute(radio.enuNormZero,[3 1 4 5 6 2]);

%radian difference from meshpoint to TX main beams
mesh.alpha = acos(dot(repmat(mesh.enuNormZero,1,1,1,1,1,nTgts),permute(radio.enuNormZero,[1 3 4 5 2 6])));
mesh.alpha = permute(mesh.alpha,[6 2 3 4 5 1]);

%need to add in actual antenna gains (not just attenuation)
mesh.FSPL = log2lin(fspl(mesh.aer(3,:,:,:,:),lambda));
mesh.power = genericPattern(mesh.alpha) .* repmat(nodes.powers',nTgts,1,N,N,N) ./ repmat(mesh.FSPL,nTgts,1,1,1,1);


mesh.phases = 2*pi * mod(repmat(mesh.aer(3,:,:,:,:),2,1,1,1,1) + ...
              repmat(radio.delays',1,1,N,N,N),lambda) / lambda;

mesh.fieldStr = permute(sum(abs(mesh.phases .* mesh.power),2),[3 4 5 1 2]);

%isosurface(mesh.fieldStr(:,:,:,1))

             

% should I solve the analytical solutions for each radiator at each point in space?
% plot power density in free space, with superimposed beams?
% should I do the same work with FSPL, time delay, and a real signal/reflection?

% maybe I should focus on receive & autocorrelation first?

% solution: compute field strength in grid around targets, by superimposing the phases of each transmitter, multiplied by their respective powers, and attenuated by FSPL



toc