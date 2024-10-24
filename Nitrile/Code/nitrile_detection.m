classdef nitrile_detection
    properties
        image
    end

    methods
        % Constructor
        function obj = nitrile_detection(prop1)
            if nargin > 0
                obj.image = prop1;
            end
        end
        
        % Detect Nitrile Stain
        function [result, message, resultImage] = detectNitrileStain(obj)

            img = obj.image;

            % Convert the image to LAB color space
            lab_image = rgb2lab(img);
            
            % Extract the 'b' channel (as nitrile gloves are often orange)
            b_channel = lab_image(:,:,3);
            
            % Thresholding the 'b' channel to isolate the orange glove color
            glove_mask = b_channel > 24 & b_channel < 80; % Adjust threshold as needed for orange color
            
            % Perform morphological operations to clean up the mask
            glove_mask = imfill(glove_mask, 'holes');
            glove_mask = bwareaopen(glove_mask, 1000); % Remove small noise regions
            
            % Use regionprops to find the largest connected component (assumed to be the glove)
            stats = regionprops('table', glove_mask, 'Area', 'PixelIdxList');
            [~, idx] = max(stats.Area);
            largest_component_mask = false(size(glove_mask));
            largest_component_mask(stats.PixelIdxList{idx}) = true;
            
            % Apply the mask to the original image
            masked_image = bsxfun(@times, img, uint8(largest_component_mask));
            
            % Convert the masked image to grayscale
            gray_masked_image = rgb2gray(img);
            
            % Apply thresholding to segment the stains
            stain_threshold = 14; % Adjust threshold as needed
            stain_mask = gray_masked_image > stain_threshold;
            
            % Optionally, perform morphological operations to refine the mask
            % Example:
            stain_mask = imopen(stain_mask, strel('disk', 17));
            
            % Invert the stain mask to show only the stains
            stain_mask_inverted = ~stain_mask;
            
            % Overlay the inverted stain mask on the original image
            overlay_image = img;
            overlay_image(stain_mask_inverted) = 255; % Set stained regions to white
            
            % Perform connected component analysis on the inverted stain mask
            cc_stains = bwconncomp(stain_mask_inverted);
            
            % Get properties of connected components
            stats_stains = regionprops(cc_stains, 'BoundingBox');
            
            % Draw bounding boxes on the original image
            resultImage = img;
            for i = 1:length(stats_stains)
                % Extract bounding box coordinates
                bbox = stats_stains(i).BoundingBox;
                
                % Draw bounding box
                resultImage = insertShape(resultImage, 'Rectangle', bbox, 'LineWidth', 4, 'Color', 'green');
            end
            
            % Set result and message
            if ~isempty(stats_stains)
                result = true;
                message = sprintf('Found %d stain(s)', length(stats_stains));
            else
                result = false;
                message = 'No stains found';
            end
        end
      

    
        % Detect Nitrile Hole
        function [result, message,resultImage] = detectNitrileTearing(obj)

            %Load the image
            img = obj.image;
        
            % Offset the image
            offsetImage = img + 25;
            hsvImg = rgb2hsv(offsetImage);
        
            % Define lower and upper bounds for glove color in HSV
            lowerBound = [0 0.395 0.451]; 
            upperBound = [0.096 1 1]; 
        
            % Create binary mask using lower and upper bounds
            gloveMask = (hsvImg(:,:,1) >= lowerBound(1) & hsvImg(:,:,1) <= upperBound(1)) & ...
                       (hsvImg(:,:,2) >= lowerBound(2) & hsvImg(:,:,2) <= upperBound(2)) & ...
                       (hsvImg(:,:,3) >= lowerBound(3) & hsvImg(:,:,3) <= upperBound(3));
        
            % Apply the binary mask to the original image
            masked_img = img .* uint8(cat(3, gloveMask, gloveMask, gloveMask));
        
            % Convert masked image to grayscale
            gray = rgb2gray(masked_img);
        
            % Convert mask to numeric
            mask = double(gray);
        
            % Add blur to reduce noise
            blurredMask = imgaussfilt(mask, 0.0005);
        
            % Threshold blur mask for binary mask
            threshold = 0.5;
            binaryMask = blurredMask > threshold;
        
            % Perform erosion with structuring element
            erodedMask = imerode(binaryMask, strel('disk', 4));
        
            % Find contours
            [B, ~] = bwboundaries(~erodedMask, 'noholes');
        
            % Initialize hole counter
            holeCounter = 0;
        
            % Draw rectangles around detected holes
            for k = 1:length(B)
                boundary = B{k};
                if length(boundary) < 20000 && length(boundary) > 100
                    x = min(boundary(:,2));
                    y = min(boundary(:,1));
                    w = max(boundary(:,2)) - x;
                    h = max(boundary(:,1)) - y;
        
                    % Draw rectangle
                    image1 = insertShape(img, 'Rectangle', [x y w h], 'Color', 'red', 'LineWidth', 2);
        
                    % Put text on top of the rectangle
                    image2 = insertText(image1, [x y-10], 'Hole', 'FontSize', 12, 'TextColor', 'red');
        
                    holeCounter = holeCounter + 1;
                end
            end
        
            % Update the result text
            if holeCounter > 0
                message = sprintf('Found %d hole(s)', holeCounter);
            else
                message = 'No Holes Were Detected';
            end
            
            
        
            % Display the result in image3
            
            resultImage = image2;
        
            result = holeCounter > 0;
        end
   

        % Detect Nitrile MissingFinger
         function [result, message,resultImage] = detectMissingFinger(obj)
            % Load the image
            img = obj.image;
        
            % Define skin and nail color ranges in RGB
            skin_color = [127, 88, 73];
            nail_color = [152, 115, 109];
            
            % Convert the image to the LAB color space
            lab_image = rgb2lab(img);
            
            % Extract the 'a' and 'b' channels
            a_channel = lab_image(:,:,2);
            b_channel = lab_image(:,:,3);
            
            % Thresholding the 'a' and 'b' channels to isolate skin and nail colors
            skin_mask = a_channel > 14 & a_channel < 20 & ...
                        b_channel > 10 & b_channel < 70; % Adjust thresholds as needed
            nail_mask = abs(double(img(:,:,1)) - nail_color(1)) < 20 & ...
                        abs(double(img(:,:,2)) - nail_color(2)) < 30 & ...
                        abs(double(img(:,:,3)) - nail_color(3)) < 30; % Adjust thresholds as needed
            
            % Combine the skin and nail masks
            finger_mask = skin_mask & ~nail_mask;
            
            % Perform morphological operations to clean up the mask
            finger_mask = imfill(finger_mask, 'holes');
            finger_mask = bwareaopen(finger_mask, 1000); % Remove small noise regions
        
            
            
            % Use regionprops to find bounding boxes around fingers
            stats = regionprops('table', finger_mask, 'BoundingBox');
            
            resultImage  = img;
            % Draw bounding boxes on the image
            for i = 1:size(stats, 1)
                bbox = stats.BoundingBox(i,:);
                resultImage = insertShape(resultImage, 'Rectangle', bbox, 'LineWidth', 2, 'Color', 'green');
            end
        
            
        
            result = size(stats, 1) > 0;
            if result
                message = sprintf('Fingers Missing: %d', size(stats, 1));
            else
                message = 'All fingers detected and the glove is fine';
            end
         end
    end

end


