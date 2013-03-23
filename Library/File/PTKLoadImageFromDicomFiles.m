function loaded_image = PTKLoadImageFromDicomFiles(path, filenames, check_files, reporting)
    % PTKLoadImageFromDicomFiles. Loads a series of DICOM files into a 3D volume
    %
    %     Syntax
    %     ------
    %
    %         loaded_image = PTKLoadImageFromDicomFiles(path, filenames, reporting)
    %
    %             loaded_image    a PTKImage containing the 3D volume
    %
    %             path, filename  specify the location to save the DICOM data. One 2D file
    %                             will be created for each image slice in the z direction. 
    %                             Each file is numbered, starting from 0.
    %                             So if filename is 'MyImage.DCM' then the files will be
    %                             'MyImage0.DCM', 'MyImage1.DCM', etc.
    %
    %             check_files     Set this to true to perform additional
    %                             checking to ensure the data is loaded in the
    %                             correct order and forms a single series.
    %                             Setting to false will result in faster
    %                             loading, but assumes all files form a single
    %                             series, and also assumes that when sorted into
    %                             numerical-alphabetical order, the files are in
    %                             the correct order
    %
    %             reporting       A PTKReporting or implementor of the same interface,
    %                             for error and progress reporting. Create a PTKReporting
    %                             with no arguments to hide all reporting. If no
    %                             reporting object is specified then a default
    %                             reporting object with progress dialog is
    %                             created
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %        

    if nargin < 3
        reporting = PTKReportingDefault;
    end
    
    progress_index = 0;

    reporting.ShowProgress('Loading images');
    reporting.UpdateProgressValue(0);
    
    filenames = PTKTextUtilities.SortFilenames(filenames);
    num_slices = length(filenames);
    
    % Load metadata and image data from first file in the list
    [metadata_first_file, first_image_slice] = ReadDicomFile(fullfile(path, filenames{1}), reporting);
    reporting.UpdateProgressValue(round(100*progress_index/num_slices));
    progress_index = progress_index + 1;

    size_i = metadata_first_file.Height;
    size_j = metadata_first_file.Width;
    size_k = num_slices;

    
    % Special case for a single image
    if num_slices == 1
        loaded_image = first_image_slice;
        slice_thickness = metadata_first_file.SliceThickness;        
    else
        % Pre-allocate image matrix
        data_type = whos('first_image_slice');
        data_type_class = data_type.class;
        if (strcmp(data_type_class, 'char'))
            reporting.ShowMessage('PTKLoadImageFromDicomFiles:SettingDatatypeToInt8', 'PTKLoadImageFromDicomFiles: char datatype detected. Setting to int8');
            data_type_class = 'int8';
        end

        % Load metadata and image data from last file in the list
        [metadata_last_file, last_image_slice] = ReadDicomFile(fullfile(path, filenames{num_slices}), reporting);

        if ~strcmp(metadata_first_file.ImageType, metadata_last_file.ImageType)
            reporting.ShowWarning('PTKLoadImageFromDicomFiles:ImageTypeMismatch', 'The first image in this series appears to be a localiser image. I am removing this from the series.');
            num_slices = num_slices - 1;
            filenames(1) = [];
            [metadata_first_file, first_image_slice] = ReadDicomFile(fullfile(path, filenames{1}), reporting);
            size_i = metadata_first_file.Height;
            size_j = metadata_first_file.Width;
            size_k = num_slices;
            [metadata_last_file, last_image_slice] = ReadDicomFile(fullfile(path, filenames{num_slices}), reporting);
        end
        reporting.UpdateProgressValue(round(100*progress_index/num_slices));
        progress_index = progress_index + 1;

        % Determine which order to load the slices in
        if isfield(metadata_first_file, 'SliceLocation') && isfield(metadata_last_file, 'SliceLocation')
            load_first_to_last = metadata_first_file.SliceLocation > metadata_last_file.SliceLocation;
            distance_between_first_and_last = abs(metadata_first_file.SliceLocation - metadata_last_file.SliceLocation);
        else
            load_first_to_last = true;
            distance_between_first_and_last = 0;
        end
        
        % These variables are only used for verifying the slice location when
        % check_files is set to true
        series_uids = repmat({''}, size_k, 1);
        slice_locations = zeros(size_k, 1);
        patient_positions = zeros(size_k, 3);
        
        if load_first_to_last
            image_index_range = 1 : size_k;
        else
            image_index_range = size_k: -1 : 1;
        end
        
        % Pre-allocate image matrix
        loaded_image = zeros(size_i, size_j, size_k, data_type_class);

        if ndims(last_image_slice) > 2
            reporting.ShowWarning('PTKLoadImageFromDicomFiles:ImageDimensionMismatch', 'The last file contains more than one image. I will only use the first image.');
            loaded_image(:, :, image_index_range(end)) = last_image_slice(:,:,1);
        else
            loaded_image(:, :, image_index_range(end)) = last_image_slice;
        end
        
        if isfield(metadata_last_file, 'SliceLocation')
            slice_locations(image_index_range(end)) = metadata_last_file.SliceLocation;
        else
            slice_locations(image_index_range(end)) = 0;
        end
        
        if isfield(metadata_last_file, 'ImagePositionPatient')
            patient_positions(image_index_range(end), :) = metadata_last_file.ImagePositionPatient';
        else
            patient_positions(image_index_range(end), :) = 0;
        end
        series_uids{image_index_range(end)} = metadata_last_file.SeriesInstanceUID;
        
        if ndims(first_image_slice) > 2
            reporting.ShowWarning('PTKLoadImageFromDicomFiles:ImageDimensionMismatch', 'The first file contains more than one image. I will only use the first image.');
            loaded_image(:, :, image_index_range(1)) = first_image_slice(:,:,1);
        else
            loaded_image(:, :, image_index_range(1)) = first_image_slice;
        end
        
        if isfield(metadata_first_file, 'SliceLocation')
            slice_locations(image_index_range(1)) = metadata_first_file.SliceLocation;
        else
            slice_locations(image_index_range(1)) = 0;
        end
        
        if isfield(metadata_first_file, 'ImagePositionPatient')
            patient_positions(image_index_range(1), :) = metadata_first_file.ImagePositionPatient';
        else
            patient_positions(image_index_range(1), :) = 0;
        end
        series_uids{image_index_range(1)} = metadata_first_file.SeriesInstanceUID;
        
        % The global origin is the DICOM patient location for the first image
        % slice
        global_origin_mm = min(patient_positions(image_index_range(1), :), patient_positions(image_index_range(end), :));
        
        % Check whether the first and last slice are from the same series. This
        % is a quick way of approximately checking if all the data is from the
        % same series. To do it properly, we need to check this for every slice.
        % We only do this if check_data is true, because processing the metadata
        % for every slice using dicominfo is very slow.
        if ~strcmp(metadata_first_file.SeriesInstanceUID, metadata_last_file.SeriesInstanceUID)
            reporting.ShowWarning('PTKLoadImageFromDicomFiles:MultipleSeriesFound', 'These images are from more than one series', []);
        end
        
        % If there are only 2 slices, we already have everything loaded
        if num_slices == 2
            if isfield(metadata_first_file, 'SliceLocation') && isfield(metadata_last_file, 'SliceLocation')
                slice_thickness = abs(metadata_last_file.SliceLocation - metadata_first_file.SliceLocation);
            else
                slice_thickness = 0;
            end
        else
        
            % Load metadata and image data from second file in the list
            [metadata_second_file, second_image_slice] = ReadDicomFile(fullfile(path, filenames{2}), reporting);            
            reporting.UpdateProgressValue(round(100*progress_index/num_slices));
            progress_index = progress_index + 1;
            loaded_image(:, :, image_index_range(2)) = second_image_slice(:,:,1);;
            
            if isfield(metadata_second_file, 'SliceLocation')
                slice_locations(image_index_range(2)) = metadata_second_file.SliceLocation;
            else
                slice_locations(image_index_range(2)) = 0;
            end
            
            if isfield(metadata_second_file, 'ImagePositionPatient')
                patient_positions(image_index_range(2), :) = metadata_second_file.ImagePositionPatient';
            else
                patient_positions(image_index_range(2), :) = 0;
            end
            series_uids{image_index_range(2)} = metadata_second_file.SeriesInstanceUID;
            
            % Check that second image is from the same series
            if ~strcmp(metadata_first_file.SeriesInstanceUID, metadata_second_file.SeriesInstanceUID)
                reporting.ShowWarning('PTKLoadImageFromDicomFiles:MultipleSeriesFound', 'These images are from more than one series', []);
            end
            
            % For the purposes of building an image volume, we take slice thickness
            % to be the spacing between adjacent slices, not the scanning slice
            % thickness (SliceThickness tag), which is different. Computing the
            % spacing using the SliceLocation tag is a more reliable
            % measure than the SpacingBetweenSlices attribute, which may not be
            % defined.
            if isfield(metadata_second_file, 'SliceLocation') && isfield(metadata_first_file, 'SliceLocation')
                slice_thickness = abs(metadata_second_file.SliceLocation - metadata_first_file.SliceLocation);
            else
                slice_thickness = 0;
            end

            % Check to see if the distance between first and last slices is what
            % we expect (if not, it may indicate that some slices are missing or
            % have a different thickness from other slices.
            computed_distance = (num_slices - 1)*slice_thickness;
            if abs(computed_distance - distance_between_first_and_last) > 0.1;
                reporting.ShowWarning('PTKLoadImageFromDicomFiles:InconsistentSliceThickness', 'Some image slices may be of different thickness, or some slices are missing', []);
            end
            
            
            
            % Load remaining files
            for file_number = 3 : size_k % file_index_to_load_range
                image_index = image_index_range(file_number);
                reporting.UpdateProgressValue(round(100*progress_index/num_slices));
                progress_index = progress_index + 1;
                next_filename_or_metadata = fullfile(path, filenames{file_number});
                
                % We only load the metadata if check_files is true, because the
                % loading and processing of metadata using dicominfo is very slow
                if check_files
                    try
                        next_filename_or_metadata = ReadMetadata(next_filename_or_metadata, reporting);
                        if isfield(next_filename_or_metadata, 'SliceLocation')
                            slice_locations(image_index) = next_filename_or_metadata.SliceLocation;
                        else
                            slice_locations(image_index) = 0;
                        end
                        if isfield(next_filename_or_metadata, 'ImagePositionPatient')
                            patient_positions(image_index, :) = next_filename_or_metadata.ImagePositionPatient';
                        else
                            patient_positions(image_index, :) = 0;
                        end
                        series_uids{image_index} = next_filename_or_metadata.SeriesInstanceUID;
                    catch exception
                        reporting.Error('PTKLoadImageFromDicomFiles:MetadataReadFailure', ['PTKLoadImageFromDicomFiles: error while reading metadata from ' filenames{file_number} '. Error:' exception.message], []);
                    end
                end
                try
                    % If check_files is true, next_file will be metadata
                    % If false, next_file will be the filename
                    next_slice = dicomread(next_filename_or_metadata);
                    loaded_image(:, :, image_index) = next_slice(:, :, 1);
                catch exception
                    reporting.Error('PTKLoadImageFromDicomFiles:DicomReadFailure', ['PTKLoadImageFromDicomFiles: error while reading file ' filenames{file_number} '. Error:' exception.message]);
                end
            end
            
            % Perform additional sorting of files and checking they are part of the
            % same series
            if check_files
                % Reorder slices according the slice position
                if all(strcmp(series_uids, series_uids{1}))
                    sort_mode = 'descend';
                    
                    [sorted_slice_locations, index_matrix] = sort(slice_locations, sort_mode);
                    patient_positions = patient_positions(index_matrix, :);
                    global_origin_mm = min(patient_positions, [], 1);
                    slice_thicknesses = abs(sorted_slice_locations(2:end) - sorted_slice_locations(1:end-1));
                    fist_nonzero_index = 1;
                    if any(slice_thicknesses == 0)
                        reporting.ShowWarning('PTKLoadImageFromDicomFiles:ZeroSliceThickness', 'This image contains more than one image at the same slice position', []);
                        fist_nonzero_index = find(slice_thicknesses > 0, 1);
                        if isempty(fist_nonzero_index)
                            fist_nonzero_index = 1;
                        end
                    end
                    slice_thickness = slice_thicknesses(fist_nonzero_index);
                    if any(slice_thicknesses - slice_thickness) > 0.01
                        reporting.ShowWarning('PTKLoadImageFromDicomFiles:InconsistentSliceThickness', 'Not all slices have the same thickness', []);
                    end
                    if max(slice_thicknesses - slice_thickness) > 0.01
                        reporting.ShowWarning('PTKLoadImageFromDicomFiles:InconsistentSliceThickness', 'Not all slices have the same thickness', []);
                    end
                    loaded_image(:,:,:) = loaded_image(:,:,index_matrix);
                else
                    reporting.ShowWarning('PTKLoadImageFromDicomFiles:MultipleSeriesFound', 'These images are from more than one series', []);
                end
            end
        end
    end
    
    % Replace padding value with zero
    if (isfield(metadata_first_file, 'PixelPaddingValue'))
        padding_value = metadata_first_file.PixelPaddingValue;
        
        padding_indices = find(loaded_image == padding_value);
        if (~isempty(padding_indices))
            reporting.ShowMessage('PTKLoadImageFromDicomFiles:ReplacingPaddingValue', ['Replacing padding value ' num2str(padding_value) ' with zeros.']);
            loaded_image(padding_indices) = 0;
        end
    end
    
    % Check for unspecified padding value in GE images
    if strcmp(metadata_first_file.Manufacturer, 'GE MEDICAL SYSTEMS')
        extra_padding_pixels = find(loaded_image == -2000);
        if ~isempty(extra_padding_pixels) && (metadata_first_file.PixelPaddingValue ~= -2000)
            reporting.ShowWarning('PTKLoadImageFromDicomFiles:IncorrectPixelPadding', 'This image is from a GE scanner and appears to have an incorrect PixelPaddingValue. This is a known issue with the some GE scanners. I am assuming the padding value is -2000 and replacing with zero.', []);
            loaded_image(extra_padding_pixels) = 0;
        end
    end
    
    loaded_image = PTKDicomImage.CreateDicomImageFromMetadata(loaded_image, metadata_first_file, slice_thickness, global_origin_mm, reporting);
    
end

function [metadata, image_data] = ReadDicomFile(file_name, reporting)
    metadata = ReadMetadata(file_name, reporting);
    try
        image_data = dicomread(metadata);
    catch exception
        reporting.Error('PTKLoadImageFromDicomFiles:DicomReadError', ['PTKLoadImageFromDicomFiles: error while reading file ' file_name '. Error:' exception.message]);
    end
end

function metadata = ReadMetadata(file_name, reporting)
    try
        metadata = dicominfo(file_name);
    catch exception
        reporting.Error('PTKLoadImageFromDicomFiles:MetaDataReadError', ['PTKLoadImageFromDicomFiles: error while reading metadata from ' file_name ': is this a DICOM file? Error:' exception.message]);
    end
    try
        image_data = dicomread(metadata);
    catch exception
        reporting.Error('PTKLoadImageFromDicomFiles:DicomReadError', ['PTKLoadImageFromDicomFiles: error while reading file ' file_name '. Error:' exception.message]);
    end
end