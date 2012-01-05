classdef TDPluginsPanel < handle
    % TDPluginsPanel. Part of the gui for the Pulmonary Toolkit.
    %
    %     You should not use this class within your own code. It is intended to
    %     be used internally within the gui of the Pulmonary Toolkit.
    %
    %     TDPluginsPanel builds and manages the panel of plugins and gui plugins
    %     as part of the Pulmonary Toolkit gui.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %
    
    properties (Access = private)
        Reporting
        PanelHandle
        PluginButtonHandlesMap
        GuiPluginPanels
        PluginPanels
        PluginsByCategory
        GuiPluginsByCategory
        
    end
    
    methods
        function obj = TDPluginsPanel(uipanel_handle, reporting)
            obj.Reporting = reporting;
            obj.PanelHandle = uipanel_handle;
            obj.GuiPluginPanels = containers.Map;
            obj.PluginPanels = containers.Map;            
        end
        
        function AddAllPreviewImagesToButtons(obj, current_dataset, window, level)
            plugin_names = obj.PluginButtonHandlesMap.keys;
            for plugin_name_cell_index = 1 : length(plugin_names)
                plugin_name = plugin_names{plugin_name_cell_index};
                obj.AddPreviewImage(plugin_name, current_dataset, window, level);
            end
        end
        
        function AddPreviewImage(obj, plugin_name, current_dataset, window, level)
            preview_image = obj.GetPreviewImage(plugin_name, current_dataset);
            obj.AddPreviewImageToButton(plugin_name, preview_image, window, level);
        end
        
        function AddPreviewImageToButton(obj, plugin_name, preview_image, window, level)
            if obj.PluginButtonHandlesMap.isKey(plugin_name)
                button_handle = obj.PluginButtonHandlesMap(plugin_name);                
                button_position = get(button_handle, 'Position');
                rgb_image = obj.GetButtonImage(preview_image, button_position(4), button_position(3), window, level);
                set(button_handle, 'CData', rgb_image);
            end
        end
        
        function AddPlugins(obj, callback_function_handle, gui_callback_function_handle, current_dataset)
            % This function adds buttons for all files in the Plugins directory
            gui_plugins_by_category = TDGuiPluginInformation.GetPluginInformation;
            plugins_by_category = TDPluginInformation.GetPluginInformation(obj.Reporting);
            obj.PluginsByCategory = plugins_by_category;
            obj.GuiPluginsByCategory = gui_plugins_by_category;
            obj.AddPluginsToPanel(gui_plugins_by_category, plugins_by_category, callback_function_handle, gui_callback_function_handle, current_dataset);
        end
        
        function RefreshPlugins(obj, callback_function_handle, gui_callback_function_handle, current_dataset, window, level)
            obj.DeletePlugins;
            obj.AddPlugins(callback_function_handle, gui_callback_function_handle, current_dataset)
            obj.Resize;
            obj.AddAllPreviewImagesToButtons(current_dataset, window, level)
        end        
        
        function Resize(obj)
            gui_plugins_by_category = obj.GuiPluginsByCategory;
            plugins_by_category = obj.PluginsByCategory;
            obj.RepositionPanels(gui_plugins_by_category, plugins_by_category);
        end        

    end
    
    
    methods (Access = private)
        function AddPluginsToPanel(obj, gui_plugins_by_category, plugins_by_category, callback_function_handle, gui_callback_function_handle, current_dataset)
            % Add plugin button to the panel
            
            obj.PluginButtonHandlesMap = containers.Map;
            
            obj.GuiPluginPanels = containers.Map;
            obj.PluginPanels = containers.Map;
            
            set(obj.PanelHandle, 'Units', 'pixels');
            panel_size = get(obj.PanelHandle, 'Position');

            max_x = panel_size(3);
            
            panel_position_y = panel_size(4);
            panel_spacing_h = 5;
            
            % Add gui-level plugins first
            for category = gui_plugins_by_category.keys
                current_category_map = gui_plugins_by_category(char(category));
                new_panel_handle = obj.NewPanel(category, current_category_map, gui_callback_function_handle);
                obj.GuiPluginPanels(char(category)) = new_panel_handle;
                new_panel_size = get(new_panel_handle, 'Position');
                panel_position_y = panel_position_y - new_panel_size(4) - panel_spacing_h;
            end
            
            % Now add dataset-level plugins
            for category = plugins_by_category.keys
                current_category_map = plugins_by_category(char(category));
                new_panel_handle = obj.NewPanel(category, current_category_map, callback_function_handle);
                obj.PluginPanels(char(category)) = new_panel_handle;
                new_panel_size = get(new_panel_handle, 'Position');
                panel_position_y = panel_position_y - new_panel_size(4) - panel_spacing_h;
            end
        end
        
        function RepositionPanels(obj, gui_plugins_by_category, plugins_by_category)
            
            set(obj.PanelHandle, 'Units', 'pixels');
            panel_size = get(obj.PanelHandle, 'Position');

            max_x = panel_size(3);
            
            panel_position_x = 5;
            panel_position_y = panel_size(4);
            panel_width = max(1, max_x - 10);
            panel_spacing_h = 5;
            
            % Add gui-level plugins first
            if ~isempty(gui_plugins_by_category);
                for category = gui_plugins_by_category.keys
                    panel_handle = obj.GuiPluginPanels(char(category));
                    current_category_map = gui_plugins_by_category(char(category));
                    obj.MovePanel(panel_handle, current_category_map, panel_position_x, panel_position_y, panel_width);
                    new_panel_size = get(panel_handle, 'Position');
                    panel_position_y = panel_position_y - new_panel_size(4) - panel_spacing_h;
                end
            end
            
            % Now add dataset-level plugins
            if ~isempty(plugins_by_category);
                for category = plugins_by_category.keys
                    panel_handle = obj.PluginPanels(char(category));
                    current_category_map = plugins_by_category(char(category));
                    obj.MovePanel(panel_handle, current_category_map, panel_position_x, panel_position_y, panel_width);
                    new_panel_size = get(panel_handle, 'Position');
                    panel_position_y = panel_position_y - new_panel_size(4) - panel_spacing_h;
                end
            end
        end

        
        function panel_handle = NewPanel(obj, panel_title, category_map, callback_function_handle)
            root_button_width = 20;
            root_button_height = 20;
            
            % Create the panel
            panel_background_colour = [0.0 0.129 0.278];
            panel_handle = uipanel('Parent', obj.PanelHandle, 'Title', panel_title, 'BorderType', 'etchedin', 'ForegroundColor', 'white', ...
                'BackgroundColor', panel_background_colour, 'Units', 'pixels' ...
                );
            
            % Add the buttons to the panel
            for current_plugin_key = category_map.keys
                current_plugin = category_map(char(current_plugin_key));
                tooltip_string = current_plugin.ToolTip;
                
                if (current_plugin.AlwaysRunPlugin)
                    font_angle = 'italic';
                    tooltip_string = [tooltip_string ' (this filter has disabled results caching)'];
                else
                    font_angle = 'normal';
                end
                
                button_width_multiple = current_plugin.ButtonWidth;
                button_height_multiple = current_plugin.ButtonHeight;
                
                button_width = button_width_multiple * root_button_width;
                button_height = button_height_multiple * root_button_height;
                
                new_position = [0 0 button_width button_height];
                
                button_text = ['<HTML><P ALIGN = RIGHT>', current_plugin.ButtonText];
                button_handle = uicontrol('Style', 'pushbutton', 'Parent', panel_handle, 'String', button_text, 'Tag', current_plugin.PluginName, ...
                    'Callback', {callback_function_handle, current_plugin.PluginName}, 'ToolTipString', tooltip_string, ...
                    'FontAngle', font_angle, 'ForegroundColor', 'white', 'FontSize', 12, 'Position', new_position);
                
                preview_image = [];
                rgb_image = obj.GetButtonImage(preview_image, button_height, button_width, [], []);
                
                set(button_handle, 'CData', rgb_image);
                
                obj.PluginButtonHandlesMap(char(current_plugin_key)) = button_handle;
            end
        end
        
        function MovePanel(obj, panel_handle, category_map, panel_position_x, panel_position_y, panel_width)
            root_button_width = 20;
            root_button_height = 20;
            button_spacing_w = 10;
            button_spacing_h = 5;
            header_height = 20;
            footer_height = 10;
            left_right_margins = 10;
            
            max_x = panel_width;
            position_x = left_right_margins;
            position_y = 0;
            
            last_y_coordinate = 0;
            row_height = 0;
            
            % Determine coordinates of buttons and the required panel size
            for current_plugin_key = category_map.keys
                current_plugin = category_map(char(current_plugin_key));
                
                button_width_multiple = current_plugin.ButtonWidth;
                button_height_multiple = current_plugin.ButtonHeight;
                
                button_width = button_width_multiple * root_button_width;
                button_height = button_height_multiple * root_button_height;
                
                current_plugin.X = position_x;
                current_plugin.Y = position_y;
                current_plugin.W = button_width;
                current_plugin.H = button_height;
                
                last_y_coordinate = position_y;
                row_height = max(row_height, button_height);
                last_row_height = row_height;
                
                category_map(char(current_plugin_key)) = current_plugin;
                
                position_x = position_x + button_spacing_w + button_width;
                if (position_x + button_width) > (max_x - button_spacing_w)
                    position_y = position_y + button_spacing_h + row_height;
                    position_x = left_right_margins;
                    row_height = 0;
                end
                
            end
            
            panel_height = last_y_coordinate + last_row_height + header_height + footer_height;
            panel_position = [panel_position_x, panel_position_y - panel_height, panel_width, panel_height];
            set(panel_handle, 'Units', 'pixels', 'Position', panel_position);
            
            % Add the buttons to the panel
            for current_plugin_key = category_map.keys
                current_plugin = category_map(char(current_plugin_key));
                
                position_x = current_plugin.X;
                button_width = current_plugin.W;
                button_height = current_plugin.H;
                position_y = panel_height - button_height - header_height - current_plugin.Y;
                
                new_position = [position_x position_y button_width button_height];
                
                button_handle = obj.PluginButtonHandlesMap(char(current_plugin_key));
                set(button_handle, 'Units', 'pixels', 'Position', new_position);                
            end
        end
        

        function DeletePlugins(obj)
            
            for plugin_handle = obj.PluginButtonHandlesMap.values
                delete(plugin_handle{1});
            end
            
            for plugin_panel_handle = obj.GuiPluginPanels.keys
                delete(obj.GuiPluginPanels(char(plugin_panel_handle)));
            end
            
            for plugin_panel_handle = obj.PluginPanels.keys
                delete(obj.PluginPanels(char(plugin_panel_handle)));
            end
            
            obj.PluginsByCategory = [];
            obj.GuiPluginsByCategory = [];
            
        end
        
    end
    
    
    methods (Access = private, Static)
        function preview_image = GetPreviewImage(plugin_name, current_dataset)
            if ~isempty(current_dataset)
                preview_image = current_dataset.GetPluginPreview(plugin_name);
            else
                preview_image = [];
            end
        end
        
        function rgb_image = GetButtonImage(image_preview, button_height, button_width, window, level)
            if ~isempty(image_preview)
                if islogical(image_preview.RawImage)
                    button_image = zeros(button_height, button_width, 'uint8');
                else
                    button_image = zeros(button_height, button_width, class(image_preview.RawImage));
                end
                
                max_height = min(button_height, image_preview.ImageSize(1));
                max_width = min(button_width, image_preview.ImageSize(2));
                
                button_image(1:max_height, 1:max_width) = image_preview.RawImage(1:max_height, 1:max_width);
                image_type = image_preview.ImageType;
                image_preview_limits = image_preview.GlobalLimits;
            else
                button_image = zeros(button_height, button_width, 'uint8');
                image_type = TDImageType.Colormap;
                image_preview_limits = [];
            end
            
            
            button_background_colour = 0*[0.0 0.129 0.278];
            button_text_colour = 150*[1, 1, 1];
                        
            if (image_type == 3) && isempty(image_preview_limits)
                disp('Warning: forcing image limits');
                image_preview_limits = [1 100];
            end
            
            [rgb_image, ~] = TDImageUtilities.GetImage(button_image, image_preview_limits, image_type, window, level);
            
            final_fade_factor = 0.3;
            rgb_image_factor = final_fade_factor*ones(size(rgb_image));
            x_range = 1 : -1/(button_height - 1) : 0;
            x_range = (1-final_fade_factor)*x_range + final_fade_factor;
            rgb_image_factor(:, 1:button_height, :) = repmat(x_range, [button_height, 1, 3]);
            rgb_image = uint8(round(rgb_image_factor.*double(rgb_image)));
            for c = 1 : 3
                color_slice = rgb_image(:, :, c);
                color_slice(button_image(:) == 0) = button_background_colour(c);
                color_slice(button_image(:) == 255) = button_text_colour(c);
                rgb_image(:, :, c) = color_slice;
                
                rgb_image(1:2, :, c) = button_text_colour(c);
                rgb_image(end, :, c) = button_text_colour(c);
                rgb_image(:, 1, c) = button_text_colour(c);
                rgb_image(:, end, c) = button_text_colour(c);
            end
        end
        
    end     
end