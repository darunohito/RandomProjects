function radio = coopTRXparams(nodes,tgts)
  c = 299792458;
  
  nNodes = length(nodes.xi); nTgts = size(tgts.aer,1);
  radio.aerVectors = zeros(nNodes,nTgts,3);
  radio.enuVectors = zeros(nNodes,nTgts,3);
  for ii = 1:nNodes
    [radio.aerVectors(ii,:,1),radio.aerVectors(ii,:,2),radio.aerVectors(ii,:,3)] = ...
      geodetic2aer(tgts.geodetic(:,1),tgts.geodetic(:,2),tgts.geodetic(:,3),...
      nodes.geodetic(ii,1),nodes.geodetic(ii,2),nodes.geodetic(ii,3),'wgs84','degrees');
  end
  
  [radio.enuVectors(:,:,1),radio.enuVectors(:,:,2),radio.enuVectors(:,:,3)] = aer2enu(radio.aerVectors(:,:,1),radio.aerVectors(:,:,2),radio.aerVectors(:,:,3))
  
  radio.enuNormZero = radio.enuVectors ./ repmat(radio.aerVectors(:,:,3),1,1,3);
  
  radio.TOF = radio.aerVectors(:,:,3) / c; %seconds, time of flight to target
  radio.offsets = zeros(1,nTgts); nodes.delays = zeros(nNodes,nTgts);
  for ii = 1:nTgts
    radio.offsets(ii) = max(radio.TOF(:,ii)); %timing offsets based on max TOF
    radio.delays(:,ii) = radio.offsets(ii) - radio.TOF(:,ii); %delays from trigger point until TX start
  end

endfunction