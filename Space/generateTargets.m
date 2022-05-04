function [tgt, h] = generateTargets(minElevationDeg,rangeWindow,rootLocation,nTgts,varargin) 
  
  plotMode = 0;
  if nargin > 4
    if strcmp(varargin{1},'plot')
      plotMode = 1;
      h = varargin{2};
    endif
  endif
  
  
  tgt.aer = zeros(nTgts,3);
  tgt.aer(:,1) = rand(nTgts,1) * 360;
  tgt.aer(:,2) = 90 - (rand(nTgts,1) * minElevationDeg);
  tgt.aer(:,3) = rangeWindow(1) + (rand(nTgts,1) * range(rangeWindow));
  
  tgt.geodetic = zeros(nTgts,3);
  [tgt.geodetic(:,1),tgt.geodetic(:,2),tgt.geodetic(:,3)] = aer2geodetic (tgt.aer(:,1),tgt.aer(:,2), tgt.aer(:,3), rootLocation(1), rootLocation(2), rootLocation(3),'wgs84','degrees'); %function appears to not handle radian arguments
  
  if plotMode == 1
    figure(h); hold on;
    scatter3(tgt.geodetic(:,2),tgt.geodetic(:,1),tgt.geodetic(:,3),'filled')
  else
    h = 0;
  endif

endfunction
