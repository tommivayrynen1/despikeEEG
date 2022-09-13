
function data = gap_inpaint(data)

    interpolated_data = data.trial{1};
    %replace artificial sections with nans
    s_e_array = data.preprocessing.badsegs;
    interpolated_data_nans = interpolated_data;
    for i =1:size(s_e_array,1) % replace artificial segments with nans
        interpolated_data_nans(:,s_e_array(i,1):s_e_array(i,2)) = NaN;  
    end


    % time domain interpolation

    corrected_raw = interpolated_data_nans;
    prewindow = 2*data.fsample;
    postwindow = 2*data.fsample;

%%
    for k = 1 : size(corrected_raw,1)
        for s = 1:size(s_e_array,1)
            start_x = s_e_array(s,1);
            end_x = s_e_array(s,2);

            fill_window = [start_x:end_x]; % Indices of time-points that will be interpolated        
            if fill_window(end) == length(corrected_raw)      % Interpolation doesn't work if fill window == last sample
                fill_window = fill_window(1:end-1);
            elseif fill_window(1) == 1
                fill_window = fill_window(2:end);
            end
            from = start_x-prewindow;
            to = end_x+postwindow;
            if from<=0
               from = 1;
            elseif to>=length(corrected_raw)
                to = length(corrected_raw);
            end

            if s > 1 && s < size(s_e_array,1) && from < s_e_array(s-1,2)   % Correct sample window so no overlap to next or previous artefacts
               from = s_e_array(s-1,2)+1;end
            if s >= 1 && s < size(s_e_array,1) && to > s_e_array(s+1,1) 
                to = s_e_array(s+1,1)-1;end


            sample_window = [from:to];      % Indices of time-points used for interpolation
            fill_indices = find(ismember(sample_window,fill_window));
            sample_window(fill_indices) = NaN; % remove fill window from sample window -> no errors

            sample_window = sample_window(~isnan(sample_window)); % remove nans from indices
            sample_values = corrected_raw(k,sample_window);

            if isnan(sample_values(end)) % Correct first or last nan in special case where, artefact is start or end
                sample_values(end) = sample_values(end-1);  
            elseif isnan(sample_values(1))
                sample_values(1) = sample_values(2);
            end


            method = 'pchip';

            %debug
            j = find(isnan(sample_values));
            j2 = find(isnan(sample_window));
            if isempty(j) == 0 || isempty(j) == 0
                error('error1 Nans found')
            end

            fill = interp1(sample_window, sample_values, fill_window, method);

            % Generate surrogate data
            diff = 0;
            dont_accept = reshape(s_e_array,1,[]);        % Check if random point is near artefact, diff = limit 
            while 1                                                                                                
                surrogate = [];
                rand_timepoint = randsample([1:length(corrected_raw)],1); 
                diff = min(abs(rand_timepoint - dont_accept));
                larger_times=s_e_array(find(s_e_array > rand_timepoint));
                t_fill=rand_timepoint+length(fill);
                check_this = larger_times-t_fill;
                if rand_timepoint + length(fill_window) >= length(corrected_raw)
                    diff = 0;
                elseif isempty(find(check_this < 0)) == 1  %diff < length(fill) &&
                    surrogate = corrected_raw(k,[rand_timepoint:1:rand_timepoint+length(fill_window)-1]);
                    if isempty(find(isnan(surrogate))) == 1
                        break
                    end
                end
            end


    %       surrogate = corrected_raw(k,[rand_timepoint:1:rand_timepoint+length(fill_window)-1]);
            surrogated = detrend(surrogate,1);        


            %debug
            j = find(isnan([fill+surrogated]));
            if isempty(j) == 0
            error('error2 Nans found')
            end

            if end_x == length(corrected_raw) % fix last NaN in special case duplikaatti toiseksi viimeisesta arvosta.
                corri = [fill+surrogated];  
                corri(end+1) = corri(end);
    %           fill_end = fill_window; fill_end(end+1) = fill_window(end)+1;
                corrected_raw(k,start_x:end_x) = corri;
            elseif start_x == 1             % fix first NaN in special case, duplikaatti toiseksi viimeisesta arvosta.
                corri = [fill+surrogated];    
                corri_2(1) = corri(1);
                corri_2(2:length(corri)+1) = corri;
                corrected_raw(k,start_x:end_x) = corri_2;
            else                            % normal case
                corri = [fill+surrogated];   
                corrected_raw(k,fill_window) = corri;

            end
        end
    end

%%
    %debug
    l = 0;
    k = [];
    for i = 1:size(interpolated_data,1)
    j = find(isnan(corrected_raw(i,:)));
    if isempty(j) == 0
        l = l+1;
        k(l)=i
        error('Nans found')
    end
    end
    raw3 = data.trial{1};
    srate = data.fsample;
    raw3 = raw3(:,:);
    raw3 = detrend(raw3')';

    fig1=figure;
    subplot(2,2,1);pspectrum(raw3(1,:),srate,'spectrogram');caxis([-2 15]); colormap('jet');
    subplot(2,2,2);pspectrum(corrected_raw(1,:),srate,'spectrogram');caxis([-2 15]); colormap('jet');
    subplot(2,2,3:4);plot(raw3(1,:),'Color','k');ylim([-500 500]);hold on;plot(corrected_raw(1,:),'Color','r');ylim([-500 500])
    title('Channel 1/256 (black = original, red = corrected)')
    scroll1 = uicontrol('Style','slider','Parent',fig1,'Units','normalized','Position',[0.15 0.02 0.7 0.025],'Value',1,'Min',1,'Max',size(corrected_raw,1),'SliderStep', [1/255 1/255]);
    set(scroll1,'Callback',@scroll_clean_data2);
    waitfor(fig1)
    
    
    data.ica_pruned=corrected_raw;
    
    function scroll_clean_data2(hObject,eventdata)

    allAxesInFigure = findall(fig1,'type','axes');
    cla(allAxesInFigure(1))
    cla(allAxesInFigure(2))
    cla(allAxesInFigure(3))

    slider_value = round(get(hObject,'Value'));
    disp(slider_value)
    k = slider_value

    subplot(2,2,1);pspectrum(raw3(k,:),srate,'spectrogram');caxis([-2 15]); colormap('jet')
    subplot(2,2,2);pspectrum(corrected_raw(k,:),srate,'spectrogram');caxis([-2 15]); colormap('jet');
    subplot(2,2,3:4);plot(raw3(k,:)-mean(raw3(k,:)),'Color','k');ylim([-500 500]);hold on;plot(corrected_raw(k,:)-mean(corrected_raw(k,:)),'Color','r');ylim([-500 500])
    title(sprintf('Channel %i/%i (black = original, red = corrected)',k,size(corrected_raw,1)))

    end
    
end
