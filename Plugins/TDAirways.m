classdef TDAirways < TDPlugin
    % TDAirways. Plugin for segmenting the pulmonary airways from CT data
    %
    %     This is a plugin for the Pulmonary Toolkit. Plugins can be run using 
    %     the gui, or through the interfaces provided by the Pulmonary Toolkit.
    %     See TDPlugin.m for more information on how to run plugins.
    %
    %     Plugins should not be run directly from your code.
    %
    %     TDAirways calls the TDTopOfTrachea plugin to find the trachea
    %     location, and then runs the library routine
    %     TDAirwayRegionGrowingWithExplosionControl to obtain the
    %     airway segmentation. The results are stored in a heirarchical tree
    %     structure.
    %
    %     The output image generated by GenerateImageFromResults creates a
    %     colour-coded segmentation image with true airway points shown as blue
    %     and explosion points shown in red.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
    
    properties
        ButtonText = 'Airways'
        ToolTip = 'Shows a segmentation of the airways illustrating deleted points'
        Category = 'Airways'

        AllowResultsToBeCached = true
        AlwaysRunPlugin = false
        PluginType = 'ReplaceOverlay'
        HidePluginInDisplay = false
        FlattenPreviewImage = true
        TDPTKVersion = '1'
        ButtonWidth = 6
        ButtonHeight = 2
        GeneratePreview = true
    end
    
    methods (Static)
        function results = RunPlugin(dataset, reporting)
            trachea_results = dataset.GetResult('TDTopOfTrachea');
            
            if dataset.IsGasMRI
                threshold = dataset.GetResult('TDThresholdGasMRIAirways');
                coronal_mode = false;
            elseif strcmp(dataset.GetImageInfo.Modality, 'MR')
                lung_threshold = dataset.GetResult('TDMRILungThreshold');
                threshold = lung_threshold.LungMask;
                threshold_raw = threshold.RawImage;
                se = ones(1, 3, 10);
                threshold_raw_c = imopen(threshold_raw, se);
                threshold.ChangeRawImage(threshold_raw_c);
                coronal_mode = true;
                
            else
                threshold = dataset.GetResult('TDThresholdLung');
                coronal_mode = false;
            end            
            
            % We use results from the trachea finding to remove holes in the
            % trachea, which can otherwise cause early branching of the airway
            % algorithm
            threshold.SetIndexedVoxelsToThis(trachea_results.trachea_voxels, true);

            start_point = trachea_results.top_of_trachea;

            maximum_number_of_generations = 15;
            explosion_multiplier = 5;

            debug_mode = TDSoftwareInfo.GraphicalDebugMode;
            results = TDAirwayRegionGrowingWithExplosionControl(threshold, start_point, maximum_number_of_generations, explosion_multiplier, coronal_mode, reporting, debug_mode);
        end
        
        function results = GenerateImageFromResults(airway_results, image_templates, reporting)
            template_image = image_templates.GetTemplateImage(TDContext.LungROI);
            results = TDGetImageFromAirwayResults(airway_results.AirwayTree, template_image, reporting);
            results_raw = results.RawImage;
            explosion_points = template_image.GlobalToLocalIndices(airway_results.ExplosionPoints);
            results_raw(explosion_points) = 3;
            results.ChangeRawImage(results_raw);
       end
    end
end