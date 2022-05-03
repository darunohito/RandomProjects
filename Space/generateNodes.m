function [nodes, h] = generateNodes(bands,info,locationWindow,nNodes,varargin) 
  
  plotMode = 0;
  if nargin > 3
    if strcmp(varargin(1),'plot')
      plotMode = 1;
    endif
  endif

  %% clip and plot
  [cbands, cinfo] = rasterclip(bands, info, locationWindow);

  nodes.long = linspace(cbands.bbox(1,1),cbands.bbox(2,1),size(cbands.data,2));
  nodes.lat = linspace(cbands.bbox(1,2),cbands.bbox(2,2),size(cbands.data,1));
  nodes.xi = randi(size(cbands.data,2),nNodes,1);
  nodes.yi = randi(size(cbands.data,1),nNodes,1);
  nodes.geodetic = [nodes.lat(nodes.yi)', nodes.long(nodes.xi)',...
                    cbands.data(sub2ind(size(cbands.data),nodes.yi,nodes.xi))];
##  nodes.x = nodes.long(nodes.xi);
##  nodes.y = nodes.lat(nodes.yi);
##  nodes.z = cbands.data(sub2ind(size(cbands.data),nodes.yi,nodes.xi))';
  nodes.center = [min(nodes.long) + range(nodes.long)/2, min(nodes.lat) + range(nodes.lat)/2];
  nodes.center = [nodes.center, interp2(nodes.long,nodes.lat,cbands.data,nodes.center(1), nodes.center(2))];
  
  if plotMode == 1
    h = figure; 
    hold on;
    mesh(nodes.long,nodes.lat,cbands.data);
    scatter3(nodes.geodetic(:,2),nodes.geodetic(:,1),nodes.geodetic(:,3),'filled');
    hold off;
    xlabel('Latitude [deg]'); ylabel('Longitude [deg]'); zlabel('Altitude [m]')
  else
    h = 0;
  endif

endfunction
