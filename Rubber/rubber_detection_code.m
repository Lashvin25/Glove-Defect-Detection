classdef rubber_detection_code
    properties
        image
    end

    methods
        % Constructor
        function obj = rubber_detection_code(prop1)
            if nargin > 0
                obj.image = prop1;
            end
        end

        % Detect Rubber Stain
        function [result,message, resultImage] = detectRubberStain(obj)
            img = obj.image;

            % Convert to grayscale
            gray_image = rgb2gray(img);
            
            % Gaussian blur for noise reduction
            blurred_image = imgaussfilt(gray_image, 1);
            
            % Thresholding to segment glove region
            threshold_value = 100;
            glove_mask = blurred_image > threshold_value;
            
            % Invert the mask to get glove region
            glove_region = imcomplement(glove_mask);
            
            % Find contours within the glove region
            glove_contours = bwboundaries(glove_region);
            
            % Create a blank mask to store anomalies
            anomaly_mask = false(size(glove_mask));
            
            % Combine all glove contours into one mask
            for k = 1:length(glove_contours)
                boundary = glove_contours{k};
                % Create a mask for the current glove contour
                mask = poly2mask(boundary(:,2), boundary(:,1), size(img, 1), size(img, 2));
                % Combine the mask with the anomaly mask
                anomaly_mask = anomaly_mask | mask;
            end
            
            % Find contours within the anomaly mask
            anomaly_contours = bwboundaries(anomaly_mask);
            
            
            % Draw contours only within the anomaly mask
            output_image = img;
            num_defects = 0;
            for k = 1:length(anomaly_contours)
                boundary = anomaly_contours{k};
                % Skip the outer boundary (glove boundary)
                if k == 1
                    continue;
                end
                output_image = draw_contour(output_image, boundary, [255, 0, 0], 2); % Draw the contour with thickness 2
                num_defects = num_defects + 1; % Increment defect count
            end
            
            % Display the original image with highlighted anomalies
            resultImage = output_image;
            
            
            % Set result and message
            if num_defects > 0
                result = true;
                message = sprintf('Found %d defect(s)', num_defects);
            else
                result = false;
                message = 'No defects found';
            end
            
            % Function to draw contour on image
            function img = draw_contour(img, contour, color, thickness)
                for i = 1:size(contour, 1)
                    x = contour(i, 2);
                    y = contour(i, 1);
                    % Set color for the pixels within the thickness range
                    img(y-thickness:y+thickness, x-thickness:x+thickness, 1) = color(1);
                    img(y-thickness:y+thickness, x-thickness:x+thickness, 2) = color(2);
                    img(y-thickness:y+thickness, x-thickness:x+thickness, 3) = color(3);
                end
            end

        end

        % Detect Rubber Missing Finger
        function [result, message,resultImage] = detectRubberMissingFinger(obj)
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
            skin_mask = a_channel > 5 & a_channel < 14 & ...
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
            
            
            % Draw bounding boxes on the image
            resultImage = img; % Initialize result image
            for i = 1:size(stats, 1)
                bbox = stats.BoundingBox(i,:);
                resultImage = insertShape(resultImage, 'Rectangle', bbox, 'LineWidth', 4, 'Color', 'green');
            end
            
            % Set result and message
            if size(stats, 1) > 0
                result = true;
                message = sprintf('Found %d finger(s) in the rubber glove', size(stats, 1));
            else
                result = false;
                message = 'All fingers found in the rubber glove';
            end

        end




        % Detect Rubber Hole
        function [result, message, resultImage] = detectRubberTear(obj)
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
            nail_mask = abs(double(img(:,:,1)) - nail_color(1)) < 20 & ...
                        abs(double(img(:,:,2)) - nail_color(2)) < 20 & ...
                        abs(double(img(:,:,3)) - nail_color(3)) < 20; % Adjust thresholds as needed
            
            % Combine the skin and nail masks
            finger_mask = skin_mask & ~nail_mask;
            
            % Perform morphological operations to clean up the mask
            finger_mask = imfill(finger_mask, 'holes');
            finger_mask = bwareaopen(finger_mask, 1000); % Remove small noise regions
            
           
            % Use regionprops to find bounding boxes around connected components
            stats = regionprops('table', finger_mask, 'BoundingBox');
            
           
            resultImage = img;
            % Draw bounding boxes on top of the image
            for i = 1:size(stats, 1)
                bbox = stats.BoundingBox(i,:);
                resultImage = insertShape(resultImage, 'Rectangle', bbox, 'Color', 'red', 'LineWidth', 2);           
            
            end
            
            % Set result and message
            if size(stats, 1) > 0
                result = true;
                message = sprintf('Found %d tear(s) in the rubber glove', size(stats, 1));
            else
                result = false;
                message = 'No tears found in the rubber glove';
            end

        end


    end
end

