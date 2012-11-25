classdef TDImageUtilities
    % TDImageCoordinateUtilities. Utility functions related to displaying images
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
        
    methods (Static)
        
        % Returns a 2D image slice and alpha information
        function [rgb_slice alpha_slice] = GetImage(image_slice, limits, image_type, window, level)
            switch image_type
                case TDImageType.Grayscale
                    rescaled_image_slice = TDImageUtilities.RescaleImage(image_slice, window, level);
                    [rgb_slice, alpha_slice] = TDImageUtilities.GetBWImage(rescaled_image_slice);
                case TDImageType.Colormap
                    [rgb_slice, alpha_slice] = TDImageUtilities.GetLabeledImage(image_slice);
                case TDImageType.Scaled
                    [rgb_slice, alpha_slice] = TDImageUtilities.GetColourMap(image_slice, limits);
            end
            
        end
        
        % Returns an RGB image from a greyscale matrix
        function [rgb_image alpha] = GetBWImage(image)
            rgb_image = (cat(3, image, image, image));
            alpha = ones(size(image));
        end

        % Returns an RGB image from a colormap matrix
        function [rgb_image alpha] = GetLabeledImage(image)
            data_class = class(image);
            if strcmp(data_class, 'double') || strcmp(data_class, 'single')
                rgb_image = label2rgb(round(image), 'lines');
            else
                rgb_image = label2rgb(image, 'lines');
            end
            alpha = int8(image ~= 0);
        end

        % Returns an RGB image from a scaled floating point scalar image
        function [rgb_image alpha] = GetColourMap(image, image_limits)
            image_limits(1) = min(0, image_limits(1));
            image_limits(2) = max(0, image_limits(2));
            positive_mask = image >= 0;
            rgb_image = zeros([size(image), 3], 'uint8');
            positive_image = abs(double(image))/abs(double(image_limits(2)));
            negative_image = abs(double(image))/abs(double(image_limits(1)));
            rgb_image(:, :, 1) = uint8(positive_mask).*(uint8(255*positive_image));
            rgb_image(:, :, 3) = uint8(~positive_mask).*(uint8(255*negative_image));
            
            alpha = int8(min(1, abs(max(positive_image, negative_image))));
        end
        
        % Rescale image to a single-byte in the range 0-255.
        function rescaled_image = RescaleImage(image, window, level)
            min_value = double(level) - double(window)/2;
            max_value = double(level) + double(window)/2;
            scale_factor = 255/(max_value - min_value);
            rescaled_image = uint8(min(((image - min_value)*scale_factor), 255));
        end  
        
        % Draws box lines around a point in all dimensions, to emphasize that
        % point. Used by the show trachea plugin.
        function image = DrawBoxAround(image, centre_point, box_size, colour)
            if length(box_size) == 1
                box_size = [box_size, box_size, box_size];
            end

            min_coords = max(centre_point - box_size, 1);
            max_coords = min(centre_point + box_size, size(image));

            image(min_coords(1):max_coords(1), min_coords(2), centre_point(3)) = colour;
            image(min_coords(1):max_coords(1), max_coords(2), centre_point(3)) = colour;
            image(min_coords(1), min_coords(2):max_coords(2), centre_point(3)) = colour;
            image(max_coords(1), min_coords(2):max_coords(2), centre_point(3)) = colour;
            
            image(centre_point(1), min_coords(2), min_coords(3):max_coords(3)) = colour;
            image(centre_point(1), max_coords(2), min_coords(3):max_coords(3)) = colour;
            image(centre_point(1), min_coords(2):max_coords(2), min_coords(3)) = colour;
            image(centre_point(1), min_coords(2):max_coords(2), max_coords(3)) = colour;
            
            image(min_coords(1), centre_point(2), min_coords(3):max_coords(3)) = colour;
            image(max_coords(1), centre_point(2), min_coords(3):max_coords(3)) = colour;
            image(min_coords(1):max_coords(1), centre_point(2), min_coords(3)) = colour;
            image(min_coords(1):max_coords(1), centre_point(2), max_coords(3)) = colour;
        end
        
        % Construct a new image of zeros or logical false, depending on the
        % image class.
        function new_image = Zeros(image_size, image_class)
            if strcmp(image_class, 'logical')
                new_image = false(image_size);
            else
                new_image = zeros(image_size, image_class);
            end
        end
        
        function ball_element = CreateBallStructuralElement(voxel_size, size_mm)
            strel_size_voxels = ceil(size_mm./(2*voxel_size));
            ispan = -strel_size_voxels(1) : strel_size_voxels(1);
            jspan = -strel_size_voxels(2) : strel_size_voxels(2);
            kspan = -strel_size_voxels(3) : strel_size_voxels(3);
            [i, j, k] = ndgrid(ispan, jspan, kspan);
            i = i.*voxel_size(1);
            j = j.*voxel_size(2);
            k = k.*voxel_size(3);
            ball_element = zeros(size(i));
            ball_element(:) = sqrt(i(:).^2 + j(:).^2 + k(:).^2);
            ball_element = ball_element <= (size_mm/2);
        end
        
        function image_to_invert = InvertImage(image_to_invert)
            image_to_invert.ChangeRawImage(image_to_invert.Limits(2) - image_to_invert.RawImage);
        end
        
        function MatchSizes(image_1, image_2)
            new_size = max(image_1.ImageSize, image_2.ImageSize);
            new_origin_1 = image_1.Origin - floor((new_size - image_1.ImageSize)/2);
            image_1.ResizeToMatchOriginAndSize(new_origin_1, new_size);
            new_origin_2 = image_2.Origin - floor((new_size - image_2.ImageSize)/2);
            image_2.ResizeToMatchOriginAndSize(new_origin_2, new_size);
        end
        
        function MatchSizesAndOrigin(image_1, image_2)
            new_origin = min(image_1.Origin, image_2.Origin);
            new_size = max(image_1.Origin + image_1.ImageSize, image_2.Origin + image_2.ImageSize) - new_origin;
            image_1.ResizeToMatchOriginAndSize(new_origin, new_size);
            image_2.ResizeToMatchOriginAndSize(new_origin, new_size);
        end
        
        function combined_image = CombineImages(image_1, image_2)
            combined_image = image_1.Copy;
            new_origin = min(image_1.Origin, image_2.Origin);
            br_coords = max(image_1.Origin + image_1.ImageSize - [1,1,1], image_2.Origin + image_2.ImageSize - [1,1,1]);
            new_size = br_coords - new_origin + [1,1,1];
            combined_image.ResizeToMatchOriginAndSize(new_origin, new_size);
            combined_image.ChangeSubImage(image_2);
        end
        
        function dt = GetNormalisedDT(seg)
            seg_raw = single(bwdist(seg.RawImage == 0)); 
            max_val = single(max(seg_raw(:)));
            seg_raw = seg_raw/max_val;
            dt = seg.BlankCopy;
            dt.ChangeRawImage(seg_raw);
            dt.ImageType = TDImageType.Scaled;
        end

        function [dt, border_image] = GetBorderDistanceTransformBySlice(image_mask, direction)
            border_image = image_mask.Copy;
            dt = image_mask.BlankCopy;
            
            % Slice by slice replace the dt image with a 2D distance transform
            for slice_index = 1 : image_mask.ImageSize(direction)
                slice = image_mask.GetSlice(slice_index, direction);
                surface_slice = TDImageUtilities.GetSurfaceFrom2DSegmentation(slice);
                border_image.ReplaceImageSlice(surface_slice, slice_index, direction);
                dt_slice = bwdist(surface_slice > 0);
                dt.ReplaceImageSlice(dt_slice, slice_index, direction);
            end
            
            border_image.ChangeRawImage(border_image.RawImage > 0);
        end

        function segmentation_2d = GetSurfaceFrom2DSegmentation(segmentation_2d)
            segmentation_2d = int8(segmentation_2d == 1);
            
            % Find pixels that are nonzero and do not have 6 nonzero neighbours
            filter = zeros(3, 3);
            filter(:) = [0 1 0 1 0 1 0 1 0];
            image_conv = convn(segmentation_2d, filter, 'same');
            segmentation_2d = (segmentation_2d & (image_conv < 4));
        end
        
        % Resamples the image by inserting additional slices in one or more
        % directions so that the image is approximately isotropic. The original
        % image data is unchanged, and the new slices are determined by
        % interpolation
        function reference_image_resampled = MakeImageApproximatelyIsotropic(reference_image, interpolation_type)
            
            % Find a voxel size to use for the registration image. We divide up thick
            % slices to give an approximately isotropic voxel size
            register_voxel_size = reference_image.VoxelSize;
            register_voxel_size = register_voxel_size./round(register_voxel_size/min(register_voxel_size));
            
            % Resample both images so they have the same image and voxel size
            reference_image_resampled = reference_image.Copy;
            
            if strcmp(interpolation_type, 'PTK smoothed binary')
                reference_image_resampled.ResampleBinary(register_voxel_size);
            else
                reference_image_resampled.Resample(register_voxel_size, interpolation_type);
            end
        end

        % Calculates an approximate distance transform for a non-isotropic input
        % image
        function dt = GetNonisotropicDistanceTransform(binary_image)
            dt = TDImageUtilities.MakeImageApproximatelyIsotropic(binary_image, '*nearest');
            dt.ChangeRawImage(bwdist(logical(dt.RawImage)));
            dt.Resample(binary_image.VoxelSize, '*nearest');
            dt.ImageType = TDImageType.Scaled;
        end

        function [results, combined_image] = ComputeDice(image_1, image_2)
            TDImageUtilities.MatchSizes(image_1, image_2);
            
            combined_image = image_1.BlankCopy;
            
            combined_image_raw = zeros(combined_image.ImageSize, 'uint8');
            
            volume_indices = find(image_1.RawImage);
            combined_image_raw(volume_indices) = 1;
            
            volume_indices = find(image_2.RawImage);
            combined_image_raw(volume_indices) = combined_image_raw(volume_indices) + 2;
            
            TP = sum(sum(sum(combined_image_raw == 3)));
            FN = sum(sum(sum(combined_image_raw == 1)));
            FP = sum(sum(sum(combined_image_raw == 2)));
            results = [];
            results.Dice = 2*TP/(2*TP+FP+FN);
            results.Precision = TP/(TP+FP);
            results.Recall = TP/(TP+FN);
            combined_image.ChangeRawImage(combined_image_raw);
        end
        
        function [dice, combined_image] = ComputeDiceWithCoronalAllowance(image_1, image_2)
            TDImageUtilities.MatchSizes(image_1, image_2);
            
            combined_image = image_1.BlankCopy;
            
            combined_image_raw = zeros(combined_image.ImageSize, 'uint8');
            
            volume_indices = find(image_1.RawImage);
            combined_image_raw(volume_indices) = 1;
            
            volume_indices = find(image_2.RawImage);
            combined_image_raw(volume_indices) = combined_image_raw(volume_indices) + 2;
            
            for coronal_index = 1 : image_1.ImageSize(1)
                slice = combined_image_raw(coronal_index, :, :);
                slice2 = convn(slice == 3, ones(3,3), 'same');
                slice2 = slice2 & (slice > 0);
                slice(slice2) = 3;
                combined_image_raw(coronal_index, :, :) = slice;
            end
            
            TP = sum(sum(sum(combined_image_raw == 3)));
            FN = sum(sum(sum(combined_image_raw == 1)));
            FP = sum(sum(sum(combined_image_raw == 2)));
            dice = 2*TP/(2*TP+FP+FN);
            combined_image.ChangeRawImage(combined_image_raw);
        end
    end
end

