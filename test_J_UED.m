clear all
close all
warning off
clc

CAPA = 20;
scheme = 'J-UERD';
MSG_SEED = 518;
SEED = 438;
H = 10;      % constraint height - default is 10 - drives the complexity/quality tradeof
tic
dirSource = 'C:\Users\Administrator\Desktop';             % input dir for all QFs
output_dir = 'C:\Users\Administrator\Desktop\schemes';                       % output dir of all schemes 
  files=dir([dirSource '\*.jpg']);
    for w=1:length(files)        
            full_image_file_name=[dirSource '\' files(w).name];
            stego_name =  [output_dir '\' files(w).name];
            
            img = jpeg_read(full_image_file_name);              
            dct_coef = img.coef_arrays{1};
            [img_h img_w]  = size(dct_coef);
            cover_size = img_h * img_w;
            dct_coef2 = dct_coef;
            % remove DC coefs;
            dct_coef2(1:8:end,1:8:end) = 0;

            nz_index = find(dct_coef < 10000000); % use all dct coefficients
            nz_number = nnz(dct_coef2); % number of non zero ac coefficients

            rand('state',SEED);  % Pseudo-random Permutation for cover elements
            r_index = randperm(length(nz_index));
            nz_dct_coef = dct_coef(nz_index(r_index));
            rand('state',MSG_SEED); % Pseudo-random Permutation for message
            
            hidden_message = double(rand(ceil(max(CAPA)*nz_number/100+1),1)>0.5);
             
            q_tab = img.quant_tables{1};
            q_tab(1,1) = 0.5*(q_tab(2,1)+q_tab(1,2));
            q_matrix = repmat(q_tab,[64 64]);
            
            %%% energy of each block
%             fun = @(block_struct) sum(sum(abs(q_tab.*block_struct.data)))*ones(8);
%             J = blockproc(dct_coef2,[8 8],fun);
            dct_coef2 = im2col(q_matrix.*dct_coef2,[8 8],'distinct');
            J2 = sum(abs(dct_coef2));
            J = ones(64,1)*J2;
            J = col2im(J,[8 8], [512 512], 'distinct'); 
            
%             decide = q_matrix./J; % version 1

            pad_size = 8;
            im2 = padarray(J,[pad_size pad_size],'symmetric'); % energies of eight-neighbor blocks
            size2 = 2*pad_size;
            im_l8 = im2(1+pad_size:end-pad_size,1:end-size2);
            im_r8 = im2(1+pad_size:end-pad_size,1+size2:end);
            im_u8 = im2(1:end-size2,1+pad_size:end-pad_size);
            im_d8 = im2(1+size2:end,1+pad_size:end-pad_size);
            im_l88 = im2(1:end-size2,1:end-size2);
            im_r88 = im2(1+size2:end,1+size2:end);
            im_u88 = im2(1:end-size2,1+size2:end);
            im_d88 = im2(1+size2:end,1:end-size2);
            JJ = (J+0.25*(im_l8+im_r8+im_u8+im_d8)+0.25*(im_l88+im_r88+im_u88+im_d88));
            decide = q_matrix./JJ; % version 2   %% 这一步有疑问  可以放在pad之前处理么？
            decide = decide(nz_index(r_index));
            decide = decide/min(decide);
                    
            costs = zeros(3, length(nz_index), 'single'); % for each pixel, assign cost of being changed
            costs(1,:) = decide;       % cost of changing the first cover pixel by -1, 0, +1
            costs(3,:) = decide;       % cost of changing the first cover pixel by -1, 0, +1

            [d stego n_msg_bits l] = stc_pm1_pls_embed(int32(nz_dct_coef)', costs, uint8(hidden_message)', H); % ternary STC embedding 
            % extr_msg = stc_ml_extract(stego, n_msg_bits, H);
            % sum(uint8(hidden_message)'~=extr_msg);
            
            em_dct_coef = dct_coef;
            em_dct_coef(nz_index(r_index)) =stego;
        
            img.coef_arrays{1} = em_dct_coef;
            jpeg_write(img,stego_name);                   % generate stego image     

    end
