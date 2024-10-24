classdef cloth_detection_code
    properties
        image
    end
    
    methods
        % Constructor
        function obj = cloth_detection_code(prop1)
            if nargin > 0
                obj.image = prop1;
            end
        end
        

        % Detect Cloth Stain
        function [result, message,resultImage] = detectClothStain(obj)
            
            % Load the image from the object
            img = obj.image;
        
            % Convert the image to LAB color space
            lab_image = rgb2lab(img);
        
            % Extract the 'b' channel (as nitrile gloves are often blue)
            b_channel = lab_image(:,:,3);
        
            % Thresholding the 'b' channel to isolate the blue glove color
            glove_mask = b_channel > -50 & b_channel < -10; % Adjust threshold as needed for blue color
        
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
            black_stain_threshold = 43; % Adjust threshold for black stains
            black_stain_mask = gray_image < black_stain_threshold;
        
            % Perform morphological operations to refine the black stain mask
            black_stain_mask = imopen(black_stain_mask, strel('disk', 20));
        
            % Overlay the inverted stain mask on the original image
            overlay_image = img;
            overlay_image(black_stain_mask) = 255; % Set stained regions to white
        
            % Define the extra gap size
            extra_gap = 20; % Adjust as needed
        
            % Create a copy of the original image to draw bounding boxes on
            image_with_boxes = img;
        
            % Loop over connected components (black stains)
            stats_black_stains = regionprops('table', black_stain_mask, 'BoundingBox');
            for i = 1:height(stats_black_stains)
                % Extract bounding box coordinates
                bbox = stats_black_stains.BoundingBox(i,:);
        
                % Add extra gap to bounding box coordinates
                bbox(1:2) = bbox(1:2) - extra_gap;
                bbox(3:4) = bbox(3:4) + 2 * extra_gap;
        
                % Draw bounding box on the image with boxes
                image_with_boxes = insertShape(image_with_boxes, 'Rectangle', bbox, 'LineWidth', 2, 'Color', 'red');
            end
        
            % Check if any stains were detected
            if isempty(stats_black_stains)
                result = false;
                message = 'No stains detected';
            else
                result = true;
                message = sprintf('Detected %d stain(s)', height(stats_black_stains));
            end
        
            % Display the result in image3
            
            resultImage = image_with_boxes;
        end
        

        % Detect Cloth Missing Finger
        function [result, message,resultImage] = detectClothMissingFinger(obj)
            
            % Load the image from the object
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
            
            % Use regionprops to find bounding boxes around fingers
            stats = regionprops('table', finger_mask, 'BoundingBox');
            
            % Draw bounding boxes on the image
            for i = 1:size(stats, 1)
                bbox = stats.BoundingBox(i,:);
                image1 = insertShape(img, 'Rectangle', bbox, 'LineWidth', 2, 'Color', 'green');
            end
        
            % Display the result in image3
            
            resultImage = image1;
        
            % Check if any fingers were detected
            if size(stats, 1) > 0
                result = true;
                message = sprintf('Detected %d missing finger(s)', size(stats, 1));
            else
                result = false;
                message = 'All fingers detected';
            end
        end


        
        %Detect Cloth Tear
        function [result, message,resultImage] = detectClothTears(obj)

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
        
            % Get region properties
            stats = regionprops('table', finger_mask, 'BoundingBox');
        
            % Check if tears are detected
            if height(stats) > 0
                result = true;
                message = [num2str(height(stats)), ' Tear(s) detected in the  Glove'];
            else
                result = false;
                message = 'No tears detected';
            end
        
            % Display the result in image3
            
            resultImage = img;
            hold on;
            for i = 1:height(stats)
                bbox = stats.BoundingBox(i,:);
                resultImage = insertShape(resultImage, 'Rectangle', bbox, 'LineWidth', 4, 'Color', 'yellow');            
            end
            
            
        end



            
        % Detect Cloth Seam
        function [result, message,resultImage] = detectClothSeam(obj)

            img = obj.image;

            % Perform open seam detection
            E = entropyfilt(img);
            Eimg = rescale(E);
        
            binary = im2bw(Eimg, 0.5);
            BWao = bwareaopen(binary, 2000);
        
            nhood = ones(9);
            closeBWao = imclose(BWao, nhood);
        
            % Create the cloth mask
            clothmask = imfill(closeBWao, 'holes');
        
            % Convert the mask to an appropriate data type for blurring
            numericMask = double(clothmask);
        
            % Apply Gaussian blurring to the mask to smoothen the edges
            sigma = 5;
            blurredMask = imgaussfilt(numericMask, sigma);
        
            % Threshold the blurred mask to obtain a binary mask
            threshold = 0.3;
            binaryMask = blurredMask > threshold;
        
            % Apply the binary mask to the original image
            detectedRegion = bsxfun(@times, img, cast(binaryMask, 'like', img));
        
            % Color image segmentation
            hsvImg = rgb2hsv(detectedRegion);
            hue = hsvImg(:,:,1);
            saturation = hsvImg(:,:,2)*2.5; 
            value = hsvImg(:,:,3);
        
            [hue, saturation, value] = rgb2hsv(hue, saturation, value);
        
            binaryMask1 = (hue > 1) | (hue < 0.5); % Create a binary mask for OSH values outside the range [0.5, 1]
            defectMask = imclearborder(binaryMask1, 4); % Remove objects touching the image border
            defectMaskErosion = imerode(defectMask, strel('disk', 6)); % Perform erosion on the mask
            defectMaskDilation = imdilate(defectMaskErosion, strel('disk', 5)); % Perform dilation on the eroded mask
            defectMask = imclearborder(defectMaskDilation, 4); % Remove objects touching the image border again
        
            sizeThreshold = 250; % Accept size of fingers that are greater or equal to 5000 pixels (finger size)
            openSeam = bwpropfilt(defectMask, 'Area', [sizeThreshold Inf]);
        
            cc = bwconncomp(openSeam);
            numOpenSeam = cc.NumObjects;
        
            % Initialize result and message
            result = numOpenSeam > 0;
            if result
                message = sprintf('%d Seam Defect(s) Detected', numOpenSeam);
            else
                message = 'No Seam Defects Detected';
            end
        
            % Loop through each open seam and perform further analysis if needed
            for i = 1:numOpenSeam
                openSeamPixels = cc.PixelIdxList{i};
        
                % Calculate the bounding box of the open seam
                [rows, cols] = ind2sub(size(openSeam), openSeamPixels);
                xmin = min(cols);
                xmax = max(cols);
                ymin = min(rows);
                ymax = max(rows);
        
                % Increase the size of the bounding box
                expansionPixels = 18;
                xmin = max(1, xmin - expansionPixels);
                xmax = min(size(img, 2), xmax + expansionPixels);
                ymin = max(1, ymin - expansionPixels);
                ymax = min(size(img, 1), ymax + expansionPixels);
        
                % Draw the expanded bounding box on the original image
                shape = 'Rectangle'; % Shape type for the bounding box
                position = [xmin, ymin, xmax-xmin, ymax-ymin]; % Bounding box position [x, y, width, height]
                img = insertShape(img, shape, position, 'Color', 'red', 'LineWidth', 4);
        
                % Add text to the bounding box
                textPosition = [xmin, ymin-25]; % Adjust the text position as needed
                textString = sprintf('Open Seam %d', i); % Customize the text string as needed
                img = insertText(img, textPosition, textString, 'FontSize', 12, 'TextColor', 'red');
            end
        
            % Display the result in image3
            
            resultImage = img;
            if result
                title(message);
            else
                title('No Seam Defects Detected');
            end
        end





    end

end
