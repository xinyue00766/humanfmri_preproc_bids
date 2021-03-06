function PREPROC = humanfmri_b10_ICA_AROMA(preproc_subject_dir, varargin)

% This function runs ICA-AROMA using python.
% (github: https://github.com/rhr-pruim/ICA-AROMA)
%
% :Usage:
% ::
%    PREPROC = humanfmri_b9_ICA_AROMA(preproc_subject_dir, varargin)
%
%
% :Input:
% ::
%
% - preproc_subject_dir     the subject directory for preprocessed data
%                             (PREPROC.preproc_outputdir)
%
% ** this is still a working version. There might still be errors.
%
% :Optional Input:
%    'ica_aroma_dir', [, dir]
%    'anaconda_dir', [, dir] 
%    'tr', [, seconds]: TR seconds (e.g., 'tr',0.46; default)
%    'overwritten'
%    'dim', [, number]: number of dimensionlity (e.g., 'dim', 200)
%
% :Output(PREPROC):
% ::
%       PREPROC.ica_aroma_outdir
%       PREPROC.ica_aroma_dir
%       PREPROC.aswr_func_bold_files
%
%       save results in PREPROC.ica_aroma_dir
%
% ..
%     Author and copyright information:
%
%     Copyright (C) Nov 2017  Choong-Wan Woo and Jaejoong Lee
%
%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
%
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
%
%     You should have received a copy of the GNU General Public License
%     along with this program.  If not, see <http://www.gnu.org/licenses/>.
% ..

% you can change the default for your computer
ica_aroma_dir = '/Users/clinpsywoo/Dropbox/github/ICA-AROMA';
anaconda_dir = [];
add_option = [];
%anaconda_dir = '/Users/clinpsywoo/anaconda/bin';
TR = 0.46; %defaults
for i = 1:numel(varargin)
    if ischar(varargin{i})
        switch varargin{i}
            case {'ica_aroma_dir'} % in seconds
                ica_aroma_dir = varargin{i+1};
            case {'anaconda_dir'}
                anaconda_dir = varargin{i+1};            
            case {'tr','TR','Tr'}                
                TR = varargin{i+1};
                if ~isnumeric(TR) 
                    error('tr must be single numeric value, check your input');
                end               
                if length(TR) ~= 1
                    error('tr must be single numeric value, check your input');
                end
            case {'overwritten'}
                add_option = [add_option ' -ow '];
            case {'dim'}
                if ~isnumeric(varargin{i+1})
                    error('number of dimension must be single numeric value, check your input');
                else
                    add_option = [add_option ' -dim ' num2str(varargin{i+1})];
                end                
        end
    end
end

%% Path setup!

setenv('PATH', [getenv('PATH') ':/usr/local/fsl/bin']);
setenv('FSLOUTPUTTYPE','NIFTI_GZ');

setenv('FSLDIR', '/usr/local/fsl');
fsldir = getenv('FSLDIR');
fsldirmpath = sprintf('%s/etc/matlab',fsldir);
path(path, fsldirmpath);
clear fsldir fsldirmpath;

addpath(genpath(ica_aroma_dir));
addpath(genpath(anaconda_dir))

ica_aroma = fullfile(ica_aroma_dir, 'ICA_AROMA.py');

% compare the space bewteen mask and data and resample if necessary
subject_dir = preproc_subject_dir{1};
PREPROC = save_load_PREPROC(subject_dir, 'load'); % load PREPROC
current_data = fmri_data([PREPROC.swr_func_bold_files{1} ',1']);
ica_mask{1} = fmri_data(fullfile(ica_aroma_dir, 'mask_csf.nii.gz'));
delete(fullfile(ica_aroma_dir, 'mask_csf.nii')); % for avoiding overlap

if compare_space(current_data, ica_mask{1})
    ica_mask{2} = fmri_data(fullfile(ica_aroma_dir, 'mask_edge.nii.gz'));
    ica_mask{3} = fmri_data(fullfile(ica_aroma_dir, 'mask_out.nii.gz'));
    
    
    for i = 1:numel(ica_mask)
        ica_mask{i} = resample_space(ica_mask{i}, current_data, 'nearest');
        ica_mask{i}.fullpath = fullfile(ica_aroma_dir, ica_mask{i}.image_names);
        [fpath, fname, fext] = fileparts(ica_mask{i}.image_names);
        if strcmp(fext, '.gz')
            ica_mask{i}.image_names = fullfile(fpath, fname);
        end
        try
            write(ica_mask{i});
        catch
            write(ica_mask{i}, 'overwrite');
        end
    end
    
    gz_mask_files = filenames(fullfile(ica_aroma_dir, '*nii.gz'));
    for i = 1:numel(gz_mask_files), delete(gz_mask_files{i}); end
    system(['gzip ' fullfile(ica_aroma_dir, '*.nii')]);
end


for subj_i = 1:numel(preproc_subject_dir)
    
    subject_dir = preproc_subject_dir{subj_i};
    PREPROC = save_load_PREPROC(subject_dir, 'load'); % load PREPROC    
    [~,a] = fileparts(subject_dir);
    print_header('ICA-AROMA', a);
    
    %PREPROC = save_load_PREPROC(subject_dir, 'load'); % load PREPROC
    PREPROC.ica_aroma_outdir = fullfile(PREPROC.preproc_outputdir, 'ica_aroma'); %
    
    % make specified mask for MELODIC
    mask = fmri_data([PREPROC.swr_func_bold_files{1} ',1']);
    mask.dat = double(mask.dat~=0);
    mask.fullpath = fullfile(PREPROC.preproc_outputdir, 'preproc_mask.nii');
    try
        write(mask);
    catch
        write(mask, 'overwrite');
    end
    
    PREPROC.preproc_mask = mask.fullpath;
    
    PREPROC.aswr_func_bold_files = prepend_a_letter(PREPROC.swr_func_bold_files, ones(size(PREPROC.swr_func_bold_files)), 'a');
    
    for run_i = 1:numel(PREPROC.swr_func_bold_files)
        PREPROC.ica_aroma_dir{run_i} = fullfile(PREPROC.ica_aroma_outdir, sprintf('run%02d', run_i));
        
        [d, f] = fileparts(PREPROC.swr_func_bold_files{run_i});
        mvmt_fname = fullfile(d, ['mvmt_' f '.txt']);
        dlmwrite(mvmt_fname, PREPROC.nuisance.mvmt_covariates{run_i}, 'delimiter','\t');
                

        % command 
        py_version = 'python2.7';
        python_dir = fullfile(anaconda_dir,py_version);
        
        command = [python_dir ' ' ica_aroma ...
            ' -in ' PREPROC.swr_func_bold_files{run_i} ...
            ' -out ' PREPROC.ica_aroma_dir{run_i} ...
            ' -mc ' mvmt_fname ...
            ' -m ' PREPROC.preproc_mask ...
            ' -tr ' num2str(TR) ...
            add_option];
        
        system(command); % run python script
               
    end
    
    % moving denoised imaging files into func folder
    for run_i = 1:numel(PREPROC.swr_func_bold_files)
        
        temp_ica_aroma_denoised_file = fullfile(PREPROC.ica_aroma_dir{run_i}, 'denoised_func_data_nonaggr.nii.gz'); %non-aggressive denoised nii.gz files
        gunzip(temp_ica_aroma_denoised_file); % unzip gzip file
        temp_ica_aroma_denoised_file = fullfile(PREPROC.ica_aroma_dir{run_i}, 'denoised_func_data_nonaggr.nii'); %non-aggressive denoised nii files        
        movefile(temp_ica_aroma_denoised_file, PREPROC.aswr_func_bold_files{run_i}); % move nii file to 'subject/func' folder
        
    end
    
end

save_load_PREPROC(subject_dir, 'save', PREPROC); % save PREPROC

end