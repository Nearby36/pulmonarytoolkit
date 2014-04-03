classdef PTKImageTemplates < handle
    % PTKImageTemplates. Part of the internal framework of the Pulmonary Toolkit.
    %
    %     You should not use this class within your own code. It is intended to
    %     be used internally within the framework of the Pulmonary Toolkit.
    %
    %     PTKImageTemplates maintains a list of template images for contexts.
    %     A context is a region of interest of the lung (e.g. lung roi, left
    %     lung, right lung, original image). For each context there can exist a
    %     template image, which is an empty image containing the correct metadata
    %     for that image. A template image allows the construction of results
    %     images with the correct metadata.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %
    
    properties (Access = private)
        
        % Template images for each context
        TemplateImages
        
        % Template-related plugins which have been run. The idea is that we will 
        % know that a template is not available because the plugin was run but 
        % no template was generated
        TemplatePluginsRun
        
        % A map of all valid contexts to their corresponding plugin
        ValidContexts
        
        % A map of all valid contexts to the function required to generate the
        % context from the result of the plugin
        TemplateGenerationFunctions
        
        % Used for persisting the templates between sessions
        DatasetDiskCache
        
        % Callback for running the plugins required to generate template images
        DatasetResults

        % Callback for error reporting
        Reporting
    end
    
    methods
        function obj = PTKImageTemplates(dataset_results, dataset_disk_cache, reporting)
            
            obj.DatasetDiskCache = dataset_disk_cache;
            obj.DatasetResults = dataset_results;
            obj.Reporting = reporting;
            
            % Create empty maps. Maps must be initialised in the constructor,
            % not as default property values. Initialising as default property
            % values results in every instance of this claas sharing the same
            % map instance
            obj.TemplateImages = containers.Map;
            obj.ValidContexts  = containers.Map;
            obj.TemplateGenerationFunctions = containers.Map;
            obj.TemplatePluginsRun = containers.Map;

            % Add valid contexts
            obj.ValidContexts(char(PTKContext.OriginalImage)) = 'PTKOriginalImage';
            obj.ValidContexts(char(PTKContext.LungROI)) = 'PTKLungROI';
            obj.ValidContexts(char(PTKContext.Lungs)) = 'PTKGetContextForLungs';
            obj.ValidContexts(char(PTKContext.LeftLung)) = 'PTKGetContextForSingleLung';
            obj.ValidContexts(char(PTKContext.RightLung)) = 'PTKGetContextForSingleLung';

            % Add handles to the functions used to generate the templates
            obj.TemplateGenerationFunctions(char(PTKContext.OriginalImage)) = @PTKCreateTemplateForOriginalImage;
            obj.TemplateGenerationFunctions(char(PTKContext.LungROI)) = @PTKCreateTemplateForLungROI;
            obj.TemplateGenerationFunctions(char(PTKContext.Lungs)) = @PTKCreateTemplateForLungs;
            obj.TemplateGenerationFunctions(char(PTKContext.LeftLung)) = @PTKCreateTemplateForSingleLung;
            obj.TemplateGenerationFunctions(char(PTKContext.RightLung)) = @PTKCreateTemplateForSingleLung;
            
            % Lobes
            for context = [PTKContext.RightUpperLobe, PTKContext.RightMiddleLobe, PTKContext.RightLowerLobe, PTKContext.LeftUpperLobe, PTKContext.LeftLowerLobe]
                obj.ValidContexts(char(context)) = 'PTKGetContextForLobe';
                obj.TemplateGenerationFunctions(char(context)) = @PTKCreateTemplateForLobe;
            end

            % Segments
            for context = [PTKContext.R_AP, PTKContext.R_P, PTKContext.R_AN, PTKContext.R_L, ...
                    PTKContext.R_M, PTKContext.R_S, PTKContext.R_MB, PTKContext.R_AB, ...
                    PTKContext.R_LB, PTKContext.R_PB, PTKContext.L_APP, PTKContext.L_APP2, ...
                    PTKContext.L_AN, PTKContext.L_SL, PTKContext.L_IL, PTKContext.L_S, ...
                    PTKContext.L_AMB, PTKContext.L_LB, PTKContext.L_PB];
                
                obj.ValidContexts(char(context)) = 'PTKGetContextForSegment';
                obj.TemplateGenerationFunctions(char(context)) = @PTKCreateTemplateForSegment;
            end
            
            % Loads cached template data
            obj.Load;
        end
        
        
        function template = GetTemplateImage(obj, context, dataset_stack)
            % Returns an image template for the requested context
            
            % Check the context is recognised
            if ~obj.ValidContexts.isKey(char(context))
                obj.Reporting.Error('PTKImageTemplates:UnknownContext', 'Context not recogised');
            end
            
            % If the template does not already exist, generate it now by calling
            % the appropriate plugin and creating a template copy
            if ~obj.TemplateImages.isKey(char(context))
                obj.Reporting.ShowWarning('PTKImageTemplates:TemplateNotFound', ['No ' char(context) ' template found. I am generating one now.'], []);
                obj.DatasetResults.GetResult(obj.ValidContexts(char(context)), dataset_stack, context);
                

                % The call to GetResult should have automatically created the
                % template image - check that this has happened
                if ~obj.TemplateImages.isKey(char(context))
                    obj.Reporting.Error('PTKImageTemplates:NoContext', 'Code error: a template should have been created by call to plugin, but was not');
                end
                
            end
            
            % return the template
            template = obj.TemplateImages(char(context));
            template = template.Copy;
        end


        function UpdateTemplates(obj, plugin_name, context, result_image, result_may_have_changed)
            % Check to see if a plugin which has been run is associated with any of
            % the contexts. If it is, create a new template image for that context
            % if one does not already exist
            
            % Check whether the plugin that has been run is the template for
            % this context
            context_char = char(context);
            if obj.ValidContexts.isKey(context_char)
                context_plugin_name = obj.ValidContexts(context_char);
                if strcmp(plugin_name, context_plugin_name)
                    
                    % Check if the result image is of a type that can be used to
                    % generate a template image
                    if ~isempty(result_image) && isa(result_image, 'PTKImage')
                        
                        % Create a new template image if required for this
                        % context, or if the template has changed
                        if (~obj.TemplateImages.isKey(context_char)) || result_may_have_changed

                            
                            if ~obj.TemplateGenerationFunctions.isKey(context_char)
                                obj.Reporting.Error('PTKImageTemplates:TemplateGenerationFunctionNotFound', 'Code error: the function handle required to generate this template was not found in the map.');
                            end
                            
                            template_function = obj.TemplateGenerationFunctions(context_char);
                            template_image = template_function(result_image, context, obj.Reporting);
                            
                            % Set the template image. Note: this may be an empty
                            % image (indicating the entire cropped region) or a
                            % boolean mask
                            obj.SetTemplateImage(context, template_image);
                        end
                    end
                    
                end
            end
        end


        function context_is_enabled = IsContextEnabled(obj, context)
            % Check to see if a context has been disabled for this dataset, due to a
            % failure when running the plugin that generates the template image for
            % that context.
        
            % Check the context is recognised
            if ~obj.ValidContexts.isKey(char(context))
                obj.Reporting.Error('PTKImageTemplates:UnknownContext', 'Context not recogised');
            end
            
            % The context is enabled unless a previous attempt to run the plugin
            % did not complete (assumed to have failed)
            context_is_enabled = ~((obj.TemplatePluginsRun.isKey(char(context))) && (~obj.TemplateImages.isKey(char(context))));
        end
        

        function NoteAttemptToRunPlugin(obj, plugin_name, context)
            % Stores the fact that a plugin has been run
            
            if obj.ValidContexts.isKey(char(context))
                context_plugin_name = obj.ValidContexts(char(context));
                if strcmp(plugin_name, context_plugin_name)                    
                    obj.MarkTemplateImage(context);
                end
            end
        end
        
        function ClearCache(obj)
            % Clears cached templates
            obj.TemplateImages = containers.Map;
            obj.TemplatePluginsRun  = containers.Map;
        end
        
    end
    
    
    methods (Access = private)

        function SetTemplateImage(obj, context, template_image)
            % Cache a template image for this context
            
            obj.TemplateImages(char(context)) = template_image;
            obj.Save;
        end
        
        function MarkTemplateImage(obj, context)
            % Cache a template image for this context
            
            if ~obj.TemplatePluginsRun.isKey(char(context))
                obj.TemplatePluginsRun(char(context)) = true;
                obj.Save;
            end
        end
        
        function Load(obj)
            % Retrieves previous templates from the disk cache
        
            if obj.DatasetDiskCache.Exists(PTKSoftwareInfo.ImageTemplatesCacheName, [], obj.Reporting)
                info = obj.DatasetDiskCache.LoadData(PTKSoftwareInfo.ImageTemplatesCacheName, obj.Reporting);
                obj.TemplateImages = info.TemplateImages;
                obj.TemplatePluginsRun = info.TemplatePluginsRun;
            end
        end
        
        function Save(obj)
            % Stores current templates in the disk cache
            
            info = [];
            info.TemplateImages = obj.TemplateImages;
            info.TemplatePluginsRun = obj.TemplatePluginsRun;
            obj.DatasetDiskCache.SaveData(PTKSoftwareInfo.ImageTemplatesCacheName, info, obj.Reporting);
        end
    end
end