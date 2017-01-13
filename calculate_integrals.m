function Integrals = calculate_integrals(log2tfdata, idxs, iunique, P, M, S, cutoff)
ngenes = size(log2tfdata,1);
ncells = length(idxs);
combinations = combnk(1:ncells,3);
lM = size(M,1);
logS = log(2*pi*S.^2);
Mu = M(1,2:end);
firstcut = find(Mu>cutoff,1,'first');

IA = zeros(ngenes, ncells);%integrals over one cell type (to use in integrals 3,4 and 5)
IAB = zeros(ncells,ncells,ngenes);%integrals over 2 cell types (to use in integrals 3,4 and 5)
IABCsame = zeros(ngenes, size(combinations,1));%integrals over 3 cell types (integral 2) muA=muB=muC 
IA_BC_Amax = zeros(ngenes, size(combinations,1));%integrals with muA < muB=muC
IA_BC_Bmax = zeros(ngenes, size(combinations,1));%integrals with muB < muA=muC
IA_BC_Cmax = zeros(ngenes, size(combinations,1));%integrals with muC < muB=muA
IABC_Amin = zeros(ngenes, size(combinations,1));%integrals with muA < muB and muA < muC
IABC_Bmin = zeros(ngenes, size(combinations,1));%integrals with muB minimum
IABC_Cmin = zeros(ngenes, size(combinations,1));%integrals with muC minimum

dm=M(1,2)-M(1,1);
ds=S(2,1)-S(1,1);

parfor i=1:ngenes
    tempIA = zeros(1,ncells);
    tempIAB = zeros(ncells,ncells,1);
    tempIABCsame = zeros(1, size(combinations,1));
    tempIA_BC_Amax = zeros(1, size(combinations,1));
    tempIA_BC_Bmax = zeros(1, size(combinations,1));
    tempIA_BC_Cmax = zeros(1, size(combinations,1));    
    tempIABC_Amin = zeros(1, size(combinations,1));
    tempIABC_Bmin = zeros(1, size(combinations,1));
    tempIABC_Cmin = zeros(1, size(combinations,1));
    Isigma = cell(ncells,1);
    Isigma2 = cell(ncells,ncells);
    diags = cell(ncells,ncells);
    data = log2tfdata(i,:);
    for j=1:ncells
        N1 = sum(iunique==idxs(j));%integrals over one cell type (to use in integrals 3,4 and 5)
        xk1 = data(ismember(iunique,idxs(j)));
        F1 = -N1*logS/2; 
        [MM,XK] = meshgrid(M(1,:),xk1);
        F1a = repmat(sum(-(MM-XK).^2,1),[lM,1]);
        F1 = F1 + F1a./(2*S.^2);
        F1 = exp(F1);
        F1 = P.*F1; 
        F1(F1~=F1) = 0;
        tempIA(1,j) = dm*ds*trapz(trapz(F1,1),2);
        Isigma{j} = ds*trapz(F1,1);%store integrals over sigma for use later
        for k=(j+1):ncells %integrals over 2 cell types (to use in integrals 3,4 and 5)
            N2 = sum(iunique==idxs(k)); N12 = N1+N2;
            xk2 = data(ismember(iunique,idxs(k)));
            xk12 = [xk1 xk2];
            F2 = -N12*logS/2; 
            [MM,XK] = meshgrid(M(1,:),xk12);
            F2a = repmat(sum(-(MM-XK).^2,1),[lM,1]);
            F2 = F2 + F2a./(2*S.^2);
            F2 = exp(F2);
            F2(F2~=F2) = 0; 
            F2 = P.*F2;
            tempIAB(j,k,1) = dm*ds*trapz(trapz(F2,1),2);
            tempIAB(k,j,1) = tempIAB(j,k,1);
            Isigma2{j,k} = ds*trapz(F2,1);
            Isigma2{k,j} = Isigma2{j,k};        
        end
    end  
    for j=1:ncells
        for k=(j+1):ncells
            AB = repmat(reshape(Isigma{j},[lM 1]),[1 lM]).*repmat(reshape(Isigma{k},[1 lM]),[lM 1]);
            AB_diag = diag(cumtrapz(cumtrapz(AB(lM:-1:1,lM:-1:1),1),2)); AB_diag = AB_diag(lM:-1:1);
            diagjk = AB_diag(2:end)'; 
            diagjk(1:(firstcut-1)) = diagjk(firstcut);
            diags{j,k} = diagjk;
            diags{k,j} = diags{j,k};
        end
    end
    
    for j=1:size(combinations,1)
        xk123 = data(ismember(iunique,idxs(combinations(j,:)))); %computation of integral over 3 cell types (integral 2)
        N123 = length(xk123);
        %F3 = ((1./sqrt(2*pi*S.^2)).^N123);
        F3 = -N123*logS/2; 
        [MM,XK] = meshgrid(M(1,:),xk123);
        F3a = repmat(sum(-(MM-XK).^2,1),[lM,1]);
        F3 = F3 + F3a./(2*S.^2);
        F3 = exp(F3);
        F3 = P.*F3; 
        F3(F3~=F3) = 0; 
        tempIABCsame(1,j) = dm*ds*trapz(trapz(F3,1),2);
        
        tempIABC_Amin(1,j) = dm^3*trapz(Isigma{combinations(j,1)}(1:lM-1).*diags{combinations(j,2),combinations(j,3)});
        tempIABC_Bmin(1,j) = dm^3*trapz(Isigma{combinations(j,2)}(1:lM-1).*diags{combinations(j,1),combinations(j,3)});
        tempIABC_Cmin(1,j) = dm^3*trapz(Isigma{combinations(j,3)}(1:lM-1).*diags{combinations(j,1),combinations(j,2)});

        
        A_BC = repmat(reshape(Isigma{combinations(j,1)},[lM 1]),[1 lM]).*repmat(reshape(Isigma2{combinations(j,2),combinations(j,3)},[1 lM]),[lM 1]);
        B_AC = repmat(reshape(Isigma{combinations(j,2)},[lM 1]),[1 lM]).*repmat(reshape(Isigma2{combinations(j,1),combinations(j,3)},[1 lM]),[lM 1]);
        C_AB = repmat(reshape(Isigma{combinations(j,3)},[lM 1]),[1 lM]).*repmat(reshape(Isigma2{combinations(j,1),combinations(j,2)},[1 lM]),[lM 1]);
        A_BC = tril(A_BC,1);
        B_AC = tril(B_AC,1);
        C_AB = tril(C_AB,1);
        tempIA_BC_Amax(1,j) = dm^2*trapz(trapz(A_BC,1),2);
        tempIA_BC_Bmax(1,j) = dm^2*trapz(trapz(B_AC,1),2);
        tempIA_BC_Cmax(1,j) = dm^2*trapz(trapz(C_AB,1),2);
    end
    IA(i,:) = tempIA;
    IAB(:,:,i) = tempIAB;
    IABCsame(i,:) = tempIABCsame;
    IABC_Amin(i,:) = tempIABC_Amin;
    IABC_Bmin(i,:) = tempIABC_Bmin;
    IABC_Cmin(i,:) = tempIABC_Cmin;
    IA_BC_Amax(i,:) = tempIA_BC_Amax;
    IA_BC_Bmax(i,:) = tempIA_BC_Bmax;
    IA_BC_Cmax(i,:) = tempIA_BC_Cmax;
end

Integrals.IA = IA;
Integrals.IAB = IAB;
Integrals.IABCsame = IABsame;
Integrals.IABC_Amin = IABC_Amin;
Integrals.IABC_Bmin = IABC_Bmin;
Integrals.IABC_Cmin = IABC_Cmin;
Integrals.IA_BC_Amax = IA_BC_Amax;
Integrals.IA_BC_Bmax = IA_BC_Bmax;
Integrals.IA_BC_Cmax = IA_BC_Cmax;

end
