function banana_detector_live
% Simplest banana-like detector using color + basic shape cues.
% Highlights detections with a GREEN perimeter and a RED bounding box + label.
% Requirements: Image Processing Toolbox + Support Package for USB Webcams.

% --- Camera setup ---
cam = webcam;                    % use webcam(2) if you have multiple
cam.Resolution = '640x480';

% --- Tunable parameters ---
% HSV thresholds for yellow (hue in [0,1])
H_MIN = 0.10; H_MAX = 0.18;      % widen to [0.09 0.20] if needed
S_MIN = 0.35; V_MIN = 0.25;      % require some saturation/brightness

AREA_MIN = 1200;                 % reject tiny blobs
ECC_MIN  = 0.70;                 % elongated shape
SOL_MIN  = 0.60;                 % solidity lower bound
SOL_MAX  = 0.95;                 % avoid perfectly convex/straight
CURVE_MIN = 0.05;                % convexity deficit: 1 - Area/ConvexArea

% --- Display setup ---
hFig = figure('Name','Banana Detector (press Q to quit)','NumberTitle','off');
set(hFig,'KeyPressFcn',@(src,ev) setappdata(src,'quit',strcmpi(ev.Key,'q')));

% --- Main loop (fixed scalar logicals) ---
while ishandle(hFig) && (isempty(getappdata(hFig,'quit')) || ~getappdata(hFig,'quit'))
    % 1) Grab frame
    rgb = snapshot(cam);
    hsv = rgb2hsv(rgb);

    % 2) Color mask (yellow-ish)
    H = hsv(:,:,1); S = hsv(:,:,2); V = hsv(:,:,3);
    mask = (H >= H_MIN & H <= H_MAX) & (S >= S_MIN) & (V >= V_MIN);

    % 3) Clean-up morphology
    mask = bwareaopen(mask, 200);                 % remove tiny specks
    mask = imclose(mask, strel('disk', 7));       % bridge small gaps
    mask = imopen(mask,  strel('disk', 3));       % smooth small noise
    mask = imfill(mask, 'holes');                 % fill interior holes

    % 4) Measure blobs + “curviness”
    stats = regionprops(mask, 'Area','BoundingBox','Eccentricity','Solidity','ConvexArea');
    isBanana = false(numel(stats),1);
    for i = 1:numel(stats)
        A   = stats(i).Area;
        ecc = stats(i).Eccentricity;
        sol = stats(i).Solidity;
        if stats(i).ConvexArea > 0
            curve = 1 - (A / stats(i).ConvexArea);   % convexity deficit (curvier -> higher)
        else
            curve = 0;
        end
        isBanana(i) = (A > AREA_MIN) & ...
                      (ecc >= ECC_MIN) & ...
                      (sol >= SOL_MIN) & (sol <= SOL_MAX) & ...
                      (curve >= CURVE_MIN);
    end

    % 5) Overlay results (GREEN perimeter + RED boxes)
    out = rgb;
    if any(isBanana)
        % green perimeter from overall mask
        perim = bwperim(mask);
        out = imoverlay_uint8(out, perim);

        % red bounding boxes + labels
        BB = vertcat(stats(isBanana).BoundingBox);
        out = insertShape(out, 'Rectangle', BB, 'LineWidth', 3, 'Color', 'red');
        for k = 1:size(BB,1)
            labelPos = [BB(k,1), max(1, BB(k,2)-18)];
            out = insertText(out, labelPos, 'banana time we ball', 'FontSize', 16, ...
                             'BoxColor', 'red', 'TextColor', 'white', 'BoxOpacity', 0.6);
        end
    end

    % 6) Show
    imshow(out, 'Parent', gca);
    title('Press Q to quit • Adjust thresholds if needed');
    drawnow;
end

% --- Cleanup ---
if isvalid(hFig), close(hFig); end
clear cam;
end

% --------- Helper: perimeter overlay in GREEN ----------
function out = imoverlay_uint8(img, perimMask)
out = img;
if ~any(perimMask(:)), return; end
perimMask3 = repmat(perimMask, [1 1 3]);
green = cat(3, zeros(size(img,1),size(img,2), 'uint8'), ...
               255*ones(size(img,1),size(img,2), 'uint8'), ...
               zeros(size(img,1),size(img,2), 'uint8'));
out(perimMask3) = green(perimMask3);
end
