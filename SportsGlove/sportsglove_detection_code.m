classdef sportsglove_detection_code
    properties
        image
    end
    
    methods
        % Constructor
        function obj = sportsglove_detection_code(prop1)
            if nargin > 0
                obj.image = prop1;
            end
        end
        
        % Detect Sport Stain
        function [result, message,resultImage] = detectSportStain(obj)
             img = obj.image;
        
            % Add offset to image and convert to HSV
            offsetImage = img + 25;
            hsvImage = rgb2hsv(offsetImage);
        
            % Extract the hue, saturation, and value channels
            hue = hsvImage(:, :, 1);
            saturation = hsvImage(:, :, 2);
            value = hsvImage(:, :, 3);
        
            % Create a binary mask using the lower and upper bounds
            gloveMask = ((hue >= 0) & (hue <= 1)) & (saturation <= 0.3) & (value <= 0.4); % black
        
            % Apply the binary mask to the original image
            masked_img = img .* uint8(cat(3, gloveMask, gloveMask, gloveMask));
        
            % Convert masked image to grayscale
            gray = rgb2gray(masked_img);
        
            % Convert mask to numeric
            mask = double(gray);
        
            % Add blur to reduce noise
            blurredMask = imgaussfilt(mask, 0.5);
        
            % Threshold blur mask for binary mask
            threshold = 0.5;
            binaryMask = blurredMask > threshold;
        
            % Find contours
            [B, ~] = bwboundaries(~binaryMask, 'noholes');
        
            % Initialize stain counter
            stainCounter = 0;
        
            % Loop through detected boundaries
            for k = 1:length(B)
                boundary = B{k};
                if length(boundary) < 20000 && length(boundary) > 40
                    x = min(boundary(:,2));
                    y = min(boundary(:,1));
                    w = max(boundary(:,2)) - x;
                    h = max(boundary(:,1)) - y;
        
                    % Draw rectangle
                    image1 = insertShape(img, 'Rectangle', [x y w h], 'Color', 'red', 'LineWidth', 2);
        
                    % Put text on top of the rectangle
                    image2 = insertText(image1, [x y-10], 'Stain', 'FontSize', 12, 'TextColor', 'red');
        
                    stainCounter = stainCounter + 1;
                end
            end
        
            % Determine text to display
            if stainCounter == 0
                message = 'No stain detected';
            else
                message = sprintf('Found %d stain(s)', stainCounter);
            end
        
            % Display the result in image3
            
            resultImage = image2;
        
            % Set result
            result = stainCounter > 0;
        end

        
        % Detect Sport Missing Finger
        function [result, message,resultImage] = detectSportMissingFinger(obj)
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
            skin_mask = a_channel > 1 & a_channel < 14 & ...
                        b_channel > 10 & b_channel < 40; % Adjust thresholds as needed
            nail_mask = abs(double(img(:,:,1)) - nail_color(1)) < 10 & ...
                        abs(double(img(:,:,2)) - nail_color(2)) < 10 & ...
                        abs(double(img(:,:,3)) - nail_color(3)) < 10; % Adjust thresholds as needed
        
            % Combine the skin and nail masks
            finger_mask = skin_mask & ~nail_mask;
        
            % Perform morphological operations to clean up the mask
            finger_mask = imfill(finger_mask, 'holes');
            finger_mask = bwareaopen(finger_mask, 1000); % Remove small noise regions
        
            % Use regionprops to find bounding boxes around fingers
            stats = regionprops('table', finger_mask, 'BoundingBox');
        
            resultImage = img;
            % Draw bounding boxes on the image
            for i = 1:size(stats, 1)
                bbox = stats.BoundingBox(i,:);
                resultImage = insertShape(resultImage, 'Rectangle', bbox, 'LineWidth', 4, 'Color', 'green');
            end
        
            
        
            % Set result and message
            if size(stats, 1) > 0
                result = true;
                message = ['Missing ', num2str(size(stats, 1)), ' Fingers Detected'];
            else
                result = false;
                message = 'No Missing Fingers Detected';
            end
        end
        


        % Detect Sport Hole
        function [result, message,resultImage] = detectSportTear(obj)
            
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
            skin_mask = a_channel > 1 & a_channel < 14 & ...
                        b_channel > 10 & b_channel < 40; % Adjust thresholds as needed
            nail_mask = abs(double(img(:,:,1)) - nail_color(1)) < 10 & ...
                        abs(double(img(:,:,2)) - nail_color(2)) < 10 & ...
                        abs(double(img(:,:,3)) - nail_color(3)) < 10; % Adjust thresholds as needed
        
            % Combine the skin and nail masks
            finger_mask = skin_mask & ~nail_mask;
        
            % Perform morphological operations to clean up the mask
            finger_mask = imfill(finger_mask, 'holes');
            finger_mask = bwareaopen(finger_mask, 1000); % Remove small noise regions
        
            % Extract contours
            contours = bwboundaries(finger_mask);
        
            
            
        
            % Draw contours on top of the image
            resultImage = img;
            for k = 1:length(contours)
                boundary = contours{k};
                x = boundary(:,2);
                y = boundary(:,1);
                xmin = min(x);
                xmax = max(x);
                ymin = min(y);
                ymax = max(y);
                resultImage = insertShape(resultImage, 'Rectangle', [xmin ymin xmax-xmin ymax-ymin], 'LineWidth', 2, 'Color', 'red');
            end
        
            hold off;
            
        
            % Set result and message
            if length(contours) > 0
                result = true;
                message = [num2str(length(contours)), ' Tear(s) Detected'];
            else
                result = false;
                message = 'No Tears Detected';
            end
        end

    end

end
