function threshold_image = TDThresholdAirway(lung_image, use_wide_threshold)
    % TDThresholdAirway. Threshold a 3D volume with typical values for air
    %
    %     This function performs a threshold operation which returns voxels
    %     which lie within typical expected ranges for CT data, and for certain
    %     MR data.
    %
    %     Syntax:
    %         threshold_image = TDThresholdAirway(lung_image, use_wide_threshold)
    %
    %         Inputs:
    %         ------
    %             lung_image - The original image in a TDImage class.
    %             use_wide_threshold - Provides a winder range of values for the
    %                 threshold, which will better segment noisy images but may
    %                 oversegment, e.g. airway walls.
    %
    %         Outputs:
    %         -------
    %             threshold_image - A binary TDImage containing the voxels which
    %                 lie within the threshold range.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %

    if ~isa(lung_image, 'TDImage')
        error('Requires a TDImage as input');
    end

    if lung_image.IsCT
        limit_1 = lung_image.RescaledToGreyscale(-1024);
        limit_2 = lung_image.RescaledToGreyscale(-775);
        
        % The wide threshold permits identification of other tissues within the
        % lung
        if exist('use_wide_threshold', 'var')
            if use_wide_threshold
                limit_2 = lung_image.RescaledToGreyscale(-400);
            end
        end
        
    elseif lung_image.IsMR
        limit_1 = 0;
        limit_2 = 250;
    else
        error('Unsupported modality');
    end
        
    raw_image = lung_image.RawImage;
    raw_image = (raw_image >= limit_1 & raw_image <= limit_2);
    
    threshold_image = lung_image.BlankCopy;
    threshold_image.ImageType = TDImageType.Colormap;
    threshold_image.ChangeRawImage(raw_image);
end