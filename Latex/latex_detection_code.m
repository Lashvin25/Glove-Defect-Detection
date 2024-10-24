classdef latex_detection_code
    properties
        image
    end
    
    methods
        % Constructor
        function obj = latex_detection_code(prop1)
            if nargin > 0
                obj.image = prop1;
            end
        end
        
        % Detect Latex Stain
        function [result, message,resultImage] = detectLatexStain(obj)
            % Load the image
            img = obj.image;
        
            % Convert the image to LAB color space
            lab_image = rgb2lab(img);
            
            % Extract the 'b' channel (as nitrile gloves are often blue)
            b_channel = lab_image(:,:,3);
            
            % Thresholding the 'b' channel to isolate the blue glove color
            glove_mask = b_channel > -40 & b_channel < -20; % Adjust threshold as needed for blue color
            
            % Perform morphological operations to clean up the mask
            glove_mask = imfill(glove_mask, 'holes');
            glove_mask = bwareaopen(glove_mask, 1000); % Remove small noise regions
            
            % Use regionprops to find the largest connected component (assumed to be the glove)
            stats = regionprops('table', glove_mask, 'Area', 'PixelIdxList');
            [~, idx] = max(stats.Area);
            largest_component_mask = false(size(glove_mask));
            largest_component_mask(stats.PixelIdxList{idx}) = true;
            
            % Apply the glove mask to the original image
            glove_image = bsxfun(@times, img, uint8(largest_component_mask));
            
            % Convert the image to grayscale
            gray_image = rgb2gray(img);
            
            % Apply thresholding to segment the black stains
            black_stain_threshold = 40; % Adjust threshold for black stains
            black_stain_mask = gray_image > black_stain_threshold;
            
            % Perform morphological operations to refine the black stain mask
            stain_mask = imopen(black_stain_mask, strel('disk', 10));
        
            % Invert the stain mask to show only the stains
            stain_mask_inverted = ~stain_mask;
            
            % Create a combined mask to detect stains only within the glove region
            combined_mask = stain_mask_inverted & largest_component_mask;
            
            % Create a copy of the original image to draw bounding boxes on
            image_with_boxes = img;
            
            % Loop over connected components (black stains)
            stats_black_stains = regionprops('table', combined_mask, 'BoundingBox');
            for i = 1:height(stats_black_stains)
                % Extract bounding box coordinates
                bbox = stats_black_stains.BoundingBox(i,:);
                
                % Draw bounding box on the image with boxes
                image_with_boxes = insertShape(image_with_boxes, 'Rectangle', bbox, 'LineWidth', 2, 'Color', 'red');
            end
            
            % Display the result in image3
            
            resultImage = image_with_boxes;
            
        
            result = height(stats_black_stains) > 0;
            message = sprintf('Found %d black stains on the glove', height(stats_black_stains));
        end

        
        % Detect Latex MissingFinger
        function [result, message,resultImage] = detectLatexMissingFinger(obj)
            % Load the image
            img = obj.image;
            
        
            % Define skin and nail color ranges in RGB
            skin_color = [91, 50, 32];
            nail_color = [160, 107, 101];
            
            % Convert the image to the LAB color space
            lab_image = rgb2lab(img);
            
            % Extract the 'a' and 'b' channels
            a_channel = lab_image(:,:,2);
            b_channel = lab_image(:,:,3);
            
            % Thresholding the 'a' and 'b' channels to isolate skin and nail colors
            % Thresholding the 'a' and 'b' channels to isolate skin and nail colors
            skin_mask = a_channel > -10 & a_channel < 20 & ...
                        b_channel > 10 & b_channel < 40; % Adjust thresholds as needed
            nail_mask = abs(double(img(:,:,1)) - nail_color(1)) < 20 & ...
                        abs(double(img(:,:,2)) - nail_color(2)) < 20 & ...
                        abs(double(img(:,:,3)) - nail_color(3)) < 20; % Adjust thresholds as needed
            
            % Combine the skin and nail masks
            finger_mask = skin_mask & ~nail_mask;
            
            % Perform morphological operations to clean up the mask
            finger_mask = imfill(finger_mask, 'holes');
            finger_mask = bwareaopen(finger_mask, 1000); % Remove small noise regions
            
            % Use regionprops to find bounding boxes around fingers
            stats = regionprops('table', finger_mask, 'BoundingBox');
            
            % Draw bounding boxes on the image
            for i = 1:size(stats, 1)
                bbox = stats.BoundingBox(i,:);
                img = insertShape(img, 'Rectangle', bbox, 'LineWidth', 2, 'Color', 'red');
            end
        
            % Display the result in image3
            
            resultImage = img;

            result = ~isempty(stats); % Check if fingers are detected
            if result
                message = sprintf('Missing Fingers Detected: %d', size(stats, 1));
            else
                message = 'All fingers detected';
            end
end

         

        % Detect Latex Tear
        function [result, message,resultImage] = detectLatexTearing(obj)
            % Load the image
            img = obj.image;
        
            % Add an offset to the image and convert to HSV color space
            offsetImage = img + 25;
            hsvImage = rgb2hsv(offsetImage);
        
            % Extract the hue, saturation, and value channels
            hue = hsvImage(:, :, 1);
            saturation = hsvImage(:, :, 2);
            value = hsvImage(:, :, 3);
        
            % Create binary mask using lower and upper bounds
            gloveMask = ((hue >= 0.5) & (hue <= 0.7)) & (saturation >= 0.15) & (value >= 0.2);
            
            % Apply the binary mask to the original image
            masked_img = img .* uint8(cat(3, gloveMask, gloveMask, gloveMask));
            
            % Convert masked image to grayscale
            gray = rgb2gray(masked_img);
            
            % Convert mask to numeric
            mask = double(gray);
            
            % Add blur to reduce noise
            blurredMask = imgaussfilt(mask, 0.005);
            
            % Threshold blur mask for binary mask
            threshold = 0.5;
            binaryMask = blurredMask > threshold;
            
            % Perform erosion with structuring element
            erodedMask = imerode(binaryMask, strel('disk', 4));
            
            % Find contours
            [B, ~] = bwboundaries(~erodedMask, 'noholes');
            
            % Initialize stain counter
            stainCounter = 0;
            
            % Draw rectangles around detected stains
            for k = 1:length(B)
                boundary = B{k};
                if length(boundary) < 20000 && length(boundary) > 50
                    x = min(boundary(:,2));
                    y = min(boundary(:,1));
                    w = max(boundary(:,2)) - x;
                    h = max(boundary(:,1)) - y;
            
                    % Draw rectangle
                    image1 = insertShape(img, 'Rectangle', [x y w h], 'Color', 'red', 'LineWidth', 2);
            
                    % Put text on top of the rectangle
                    image2 = insertText(image1, [x y-10], 'Hole', 'FontSize', 12, 'TextColor', 'red');
            
                    stainCounter = stainCounter + 1;
                end
            end
            
            % Update the result text
            if stainCounter > 0
                message = sprintf('Found %d hole(s)', stainCounter);
            else
                message = 'No Holes Were Detected';
            end
            
            
            % Display the result in image3
            
            resultImage = image2;
        
            result = stainCounter > 0;
            
        end




    end


end