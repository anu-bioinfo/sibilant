function [tlikely_ind, plikely_ind, ncandidates] = process_one_triplet(icomb, Integrals, Params, tripdata, makeplot, labs)	
    allodds = Params.oddsrange;
    topology_prior = Params.topology_prior;
    plikely_thresh = Params.plikely_thresh;
	
	%find p(g_i|T,b_i) for each gene starting from integrals
    [pgi_mas_T, pgi_sla] = calc_pgi_topo(icomb,Integrals, Params, tripdata);

	pT_g = zeros(length(allodds),4); %pT_g as a function of prior odds
    odds_mas_sla_T = pgi_mas_T./(pgi_sla*ones(1,4)); % See Equation (18)
    odds_mas_sla_T(odds_mas_sla_T~=odds_mas_sla_T) = 1;
    odds_mas_sla_T(odds_mas_sla_T==Inf) = 1;
    for i = 1:length(allodds)
        prior_odds = allodds(i); %p(beta_i = 1)/p(beta_i = 0) Equation (21)
        odds = 1+ prior_odds*odds_mas_sla_T;
        sum_log_odds = sum(log(odds));
        prododds = exp(sum_log_odds - max(sum_log_odds)); %divide by max(prod(odds)) to avoid Inf
        pT_g(i,:) = prododds.*topology_prior/sum(topology_prior.*prododds); % this is Equation (20)
    end
    
	greaterthan0 = pT_g(:,1:3) > plikely_thresh; 
	ncandidates = sum(sign(sum(greaterthan0))); %how many topologies have probability greater than plikely_thresh

	[tlikely_ind, plikely_ind] = find_Tlikely(pT_g);
    
    if makeplot
        %make a dot plot
        pgi_mas_Tmin = [3*Integrals.IABC_Amin(:,icomb) 3*Integrals.IABC_Bmin(:,icomb) 3*Integrals.IABC_Cmin(:,icomb)]; %find p(g_i | b_i=1, cell T is min)
        [~,imax] = max(pgi_mas_Tmin,[],2); %find cell type that gene i votes against
        figure; semilogx(odds_mas_sla_T,4-imax,'.'); 
        axis([1e-10 10*max(allodds) 0 4]); set(gca,'YTick', 1:3, 'YTickLabel', labs([3 2 1])) %plot boundaries
        xlabel('Odds of being transition gene given data'); ylabel('Cell type in which gene is downregulated');
        set(gcf,'color','w');

        %plot p(T|{g}) as a function of p(b_i=1)/p(b_i=0)
        figure; semilogx(allodds, pT_g, 'LineWidth', 2); 
        legend(labs{1},labs{2},labs{3},'null', 'Location', 'northwest'); 
        axis([min(allodds) max(allodds) -0.05 1.05])
        xlabel('prior odds'); ylabel('p(T|{g})');
        set(gcf,'color','w');
    end
end


function [tlikely_ind, plikely_ind] = find_Tlikely(pT_g)
    [m,itmax] = max(pT_g,[],2); %find most likely topology over range of odds
    itmaxnot4 = find(itmax~=4);
    [not4, itnot4] = max(m(itmaxnot4));
    if isempty(itmaxnot4)
        tlikely_ind = 0;
        plikely_ind = max(m);
    else
        tlikely_ind = itmax(itmaxnot4(itnot4));
        plikely_ind = not4;
    end
end

function [pgi_mas_T, pgi_sla, pgi_sym] = calc_pgi_topo(icomb,Integrals, Params, data)

    log_asym_min = Params.log_asym_min;
    log_sym_min = Params.log_sym_min;
    filter_min = Params.filter_min;
    psla = Params.psla;

    pgi_sla_1 = Integrals.IABCsame(:,icomb); %p(gi | alpha_i = 0, beta_i = 0) (Equation 9)
    pgi_sla_2Amax = 2*Integrals.IA_BC_Amax(:,icomb); pgi_sla_2Amax(pgi_sla_2Amax<0) = 0; %(this is unlikely: should all be > 0
    pgi_sla_2Bmax = 2*Integrals.IA_BC_Bmax(:,icomb); pgi_sla_2Bmax(pgi_sla_2Bmax<0) = 0; % but I did find one floating point error)
    pgi_sla_2Cmax = 2*Integrals.IA_BC_Cmax(:,icomb); pgi_sla_2Cmax(pgi_sla_2Cmax<0) = 0; %p(gi | alpha_i = 1, beta_i = 0) Equation (8)

    pgi_sym = [pgi_sla_2Amax pgi_sla_2Bmax pgi_sla_2Cmax];

    pgi_mas_Tmin = 3*[Integrals.IABC_Amin(:,icomb) Integrals.IABC_Bmin(:,icomb) Integrals.IABC_Cmin(:,icomb)]; %p(gi | beta_i = 1, cell type T is a leaf)
    pgi_mas_T = (1/2)*[pgi_mas_Tmin(:,2)+pgi_mas_Tmin(:,3) pgi_mas_Tmin(:,1)+pgi_mas_Tmin(:,3) pgi_mas_Tmin(:,2)+pgi_mas_Tmin(:,1)]; %p(gi | beta_i = 1, topology T) Equation (4)
    
    pgi_sla = psla(1)*pgi_sla_1 + psla(2)*pgi_sla_2Amax + psla(3)*pgi_sla_2Bmax + psla(4)*pgi_sla_2Cmax; % p(g_i | beta_i = 0) See Equation (14)

    if filter_min %some additional coarse filtering if option chosen
        expressed = data>log_asym_min;
        sym_expressed = data>log_sym_min;
        pgi_mas_T = pgi_mas_T.*expressed.*((sum(expressed,2)>1)*ones(1,3));%transition genes above expression threshold in at least 2 cell types
        pgi_sym = pgi_sym.*sym_expressed;%marker genes above expression threshold "marked" cell type
    end

    pgi_mas_0 = (1/3)*sum(pgi_mas_T,2); %p(g_i | b_i = 1, T = null) Equation (6), Equation (7)
    pgi_mas_T = [pgi_mas_T pgi_mas_0]; %p(g_i | b_i = 1, T)

end
