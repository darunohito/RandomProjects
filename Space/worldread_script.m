% pkg load mapping
% pkg load parallel
tic
close all

c = 299792458;
nNodes = 4; nTgts = 2; fCenter = 100e6; 
ROI = 1000; %radial meters around radiation pattern main lobes and target
azimuthSteps = 16;
elevationSteps = 16;
N = 100;

function rho = genericPattern(theta)
  rho = abs(sinc(theta));
endfunction

function [a] = fspl(r, lamdba)
  a = 20*log10(((4*pi)*r)/lamdba);
end

function pLog = lin2log(pLin)
  pLog = 10*log10(pLin);
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

[nodes, h] = generateNodes(bands,info,powerWindow,locationWindow,nNodes,'plot');
[tgts, h] = generateTargets(tgtMinElevationDeg,tgtRangeWindow,nodes.center,nTgts,'plot',h); 
radio = coopTRXparams(nodes, tgts);

mesh.geodetic = zeros(1,3,nTgts);
mesh.azi = linspace(0,360*(1-1/azimuthSteps),azimuthSteps);
mesh.ele = linspace(90*(1-1/elevationSteps),0,elevationSteps);
mesh.searchPattern = [repmat(mesh.azi,elevationSteps,1)' repmat(mesh.ele,azimuthSteps,1)];
mesh.search = zeros(nNodes,elevationSteps,azimuthSteps);


mesh.geodetic = linspace([nodes.lat(1) nodes.long(1) min(nodes.geodetic(:,3))],...
                         [nodes.lat(end) nodes.long(end) max(nodes.geodetic(:,3))],N);
mesh.powers = zeros(N,N,N,nNodes,nTgts);
mesh.phases = zeros(N,N,N,nNodes,nTgts);

lambda = c / fCenter;

parfor ii = mesh.geodetic(1,:)
  for jj = mesh.geodetic(2,:)
    for kk = mesh.geodetic(3,:)
      % mesh.nodeAer = geodetic2aer(ii, jj, kk, nodes.geodetic(:,1),nodes.geodetic(:,2),nodes.geodetic(:,3),'wgs84','degrees');   
      
      [t1,t2,t3] = geodetic2aer(repmat(ii,nNodes,1), repmat(jj,nNodes,1), repmat(kk,nNodes,1), nodes.geodetic(:,1),nodes.geodetic(:,2),nodes.geodetic(:,3),'wgs84','degrees');
      
      [xm,ym,zm] = aer2enu(t1,t2,t3); % m, cartesian displacement from each node to each mesh point
      
      
      alpha = zeros(nTgts,nNodes); %radian difference from meshpoint main beams
      for ll = 1:nTgts
        alpha(ll,:) = acos(dot(([xm,ym,zm]./repmat(t3,1,3))',[radio.enuNormZero(:,ll,1),radio.enuNormZero(:,ll,2),radio.enuNormZero(:,ll,3)]'))';
      end
      gain = genericPattern(alpha); % linear power gain from antenna
      power = gain .* repmat(nodes.powers',nTgts,1);
      logPower = lin2log(power);
      FSPL = fspl(t3,lambda);
      
      mesh.logPower = logPower - repmat(FSPL',nTgts,1);
##      for ll = 1:nTgts
##        
##      endfor
    endfor
  endfor
endparfor


##for ii = 1:nTgts
##  mesh.geodetic(1,:,ii) = nodes.center;
##  rr_n = repmat(0.001,nNodes,1); rr_t = 0.001;
##  basepoint = nodes.geodetic(:,:);
##  while min(rr_n) < ROI
##    
##    [mesh.geodetic(end+1:end+nNodes,1,ii),mesh.geodetic(end+1:end+nNodes,2,ii),mesh.geodetic(end+1:end+nNodes,3,ii)] = aer2geodetic (radio.aerVectors(:,1),radio.aerVectors(:,2), rr_n, basepoint(:,1),basepoint(:,2),basepoint(:,3),'wgs84','degrees'); 
##    
##    [basepoint(:,1),basepoint(:,2),basepoint(:,3)]= aer2geodetic (radio.aerVectors(:,1),radio.aerVectors(:,2), rr_n, basepoint(:,1),basepoint(:,2),basepoint(:,3),'wgs84','degrees'); 
##  
##  end
##  while rr_t < ROI
##    
##  endwhile
##  %geodetic2aer(nodes.geodetic(:,1),nodes.geodetic(:,2),nodes.geodetic(:,3),...
##end


             

% should I solve the analytical solutions for each radiator at each point in space?
% plot power density in free space, with superimposed beams?
% should I do the same work with FSPL, time delay, and a real signal/reflection?

% maybe I should focus on receive & autocorrelation first?

% solution: compute field strength in grid around targets, by superimposing the phases of each transmitter, multiplied by their respective powers, and attenuated by FSPL



toc