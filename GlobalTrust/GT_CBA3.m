function [FP_prob, FN_prob, TP_prob, d, RMSE] = GT_CBA3(alpha, mp, Dist, decision)
% alpha : probability that malicious node drops a packet
% mnode : The number of malicious nodes
% Dist : one-hop wireless radio range(m)
% decision : decision coefficient

N = 92;                         % The number of nodes
ttime = 300;                     % time for compute the reputation(min)
forwarding = 0.95;              % forwarding probability
gamma = 0.7;                    % gamma coefficient
mnode = round(N*mp);

% Set honesty nodes & malicious nodes
% honesty node : 0, malicious node : 1
node = zeros(N,ttime/30+2);
temp_mali = randperm(92);
mali_node = temp_mali(1:mnode);
for k = 1:mnode
    for l = 1:N
        if l == mali_node(k)
            node(l,1) = 1;
        end
    end
end
TA = temp_mali(mnode+1);

while sum(node(:,2)) < (N-mnode)/2
    for k = 1:N-mnode
        half = rand(1,1);
        if node(temp_mali(k+mnode),2) == 0
            if half > 0.5
                node(temp_mali(k+mnode),2) = 1;
            end
        end
        if sum(node(:,2)) == (N-mnode)/2
            break;
        end
    end
end

% load gps data
for k = 1:N
    gps = fopen(sprintf('./KAIST/KAIST_30sec_0%02d.txt', k), 'r');
    temp = fscanf(gps, '%g %g %g', [3 (2*ttime)]);
    if max(size(temp)) < (2*ttime)
        for l = max(size(temp))+1 : (2*ttime)
            temp(1,l) = 30*(l-1);
            temp(2,l) = NaN;
            temp(3,l) = NaN;
        end
    end
    if k == 1
        node_data = temp;
    else
        node_data = [node_data; temp(2, :); temp(3, :)];
    end
end
node_data = node_data';

% Calculate TA's reputation
d = zeros(ttime/30, 1);
BR = zeros(N,ttime/30);

for i = 1:(ttime/30)    
    % Set behavior of nodes
    p_events = zeros(N,N);
    n_events = zeros(N,N);
    for k = 1:N
        for l = 1:60
            prob_a = rand(92,50);
            prob_b = rand(92,50);
            neighbor = 0;
            request_node = 0;
            for m = 1:N
                % Calculate distance between nodes
                dist = sqrt((node_data(l+60*(i-1),2*k)-node_data(l+60*(i-1),2*m)).^2 + (node_data(l+60*(i-1),(2*k)+1)-node_data(l+60*(i-1),(2*m)+1)).^2);
                if k ~= m && dist <= Dist
                    if neighbor == 0
                        neighbor = m;
                    else
                        neighbor = [neighbor; m];
                    end                                                    
                end            
            end
            
            temp_size = max(size(neighbor));
            temp = randperm(temp_size);
            for j = 1:temp_size
                if neighbor == 0                    
                    break;
                elseif p_events(k,neighbor(temp(j))) == 0
                    request_node = neighbor(temp(j));
                    break;
                else
                    request_node = neighbor(temp(temp_size));
                end
            end
            for n = 1:50
                if request_node == 0
                    break;
                end
                if node(k,1) == 0
                    % honesty node
                    if node(request_node,1) == 0
                        if prob_a(request_node,n) <= forwarding 
                            if prob_b(request_node,n) <= 0.95
                                p_events(k,request_node) = p_events(k,request_node) + 1;
                            else
                                n_events(k,request_node) = n_events(k,request_node) + 1;
                            end 
                        else
                            if prob_b(request_node,n) <= 0.95
                                n_events(k,request_node) = n_events(k,request_node) + 1;
                            else
                                p_events(k,request_node) = p_events(k,request_node) + 1;
                            end
                        end
                    % malicious node
                    else                    
                        if node(k,2) == 1
                            if prob_a(request_node,n) <= alpha 
                                if prob_b(request_node,n) <= 0.95
                                    n_events(k,request_node) = n_events(k,request_node) + 1;
                                else
                                    p_events(k,request_node) = p_events(k,request_node) + 1;
                                end 
                            else 
                                if prob_b(request_node,n) <= 0.95
                                    p_events(k,request_node) = p_events(k,request_node) + 1;
                                else
                                    n_events(k,request_node) = n_events(k,request_node) + 1;
                                end
                            end
                        else
                            if prob_a(request_node,n) <= forwarding 
                                if prob_b(request_node,n) <= 0.95
                                    p_events(k,request_node) = p_events(k,request_node) + 1;
                                else
                                    n_events(k,request_node) = n_events(k,request_node) + 1;
                                end     
                            else
                                if prob_b(request_node,n) <= 0.95
                                    n_events(k,request_node) = n_events(k,request_node) + 1;
                                else
                                    p_events(k,request_node) = p_events(k,request_node) + 1;
                                end
                            end
                        end
                    end
                else
                    if node(request_node,1) == 1
                        p_events(k, request_node) = p_events(k, request_node) + 1;
                    else
                        n_events(k, request_node) = n_events(k, request_node) + 1;
                    end
                end
            end 
        end
    end


    % LTO & d
    LTO = zeros(N,N);
    for k = 1:N
        for l = 1:N
            if k == l || (p_events(k,l)+n_events(k,l)) == 0
                LTO(k,l) = NaN;                           
            else
                LTO(k,l) = p_events(k,l)/(p_events(k,l)+n_events(k,l));
                d(i) = d(i) + 1;
            end           
        end
    end
    d(i) = d(i)/(N*(N-1));

    % Similarity
    si = zeros(N,N);
    LTO_for_sim = (LTO .*2) -1;
    LTO_for_sim(isnan(LTO_for_sim)) = 0;
    for k = 1:N    
        for l = 1:N       
            norm_k = sqrt(sum(LTO_for_sim(k,:) .^2));
            norm_l = sqrt(sum(LTO_for_sim(l,:) .^2));
            nu = sum(LTO_for_sim(k,:) .* LTO_for_sim(l,:));
            si(k,l) = nu / (norm_k * norm_l);
            if si(k,l) < 0 || isnan(si(k,l)) == 1
                si(k,l) = 0;
            end
        end
    end

    % SR
    SR = zeros(N,N);
    HR = ones(1,N);
    HR(TA) = 2;
    SR_deno = zeros(N,N);
    sum_HR = zeros(N,N);
    temp_LTO = LTO;
    temp_LTO(isnan(temp_LTO)) = 0;

    S_check = zeros(N,1);
    for k = 1:N    
        for l = 1:N
            S_check(k) = S_check(k) + isnan(LTO(l,k));
        end
    end

    for k = 1:N
        for l = 1:N
            for m = 1:N
                if isnan(LTO(m,l)) == 0
                    SR_deno(k,l) = SR_deno(k,l) + (HR(m)*si(k,m));
                    sum_HR(k,l) = sum_HR(k,l) + HR(m);
                end
            end
        end    
    end
    
    for k = 1:N
        for l = 1:N
            if SR_deno(k,l) ~= 0
                for m = 1:N
                    if isnan(LTO(m,l)) == 0
                        SR(k,l) = SR(k,l) + (temp_LTO(m,l)*((HR(m)*si(k,m))/SR_deno(k,l)));
                    end
                end
            elseif SR_deno(k,l) == 0 && S_check(l) ~= N 
                for m = 1:N
                    if isnan(LTO(m,l)) == 0
                        SR(k,l) = SR(k,l) + (temp_LTO(m,l)*(HR(m)/sum_HR(k,l)));
                    end
                end
            else
                SR(k,l) = NaN;
            end
        end
    end

    % D
    SR_for_dist = SR;
    SR_for_dist(isnan(SR_for_dist)) = 0; 
    SR_dist = zeros(N,N);
    for k = 1:N
        for l = 1:N
            SR_dist(k,l) = sqrt(sum((SR_for_dist(k,:)-SR_for_dist(l,:)).^2));
        end
    end

    D = zeros(1,1);
    D_num = N;
    cul_num = 0;
    Z = linkage(SR_dist);
    while D_num > N/2    
        cul_num = cul_num + 1;
        cluster_size = zeros(1,2);
        W = cluster(Z,'maxclust', cul_num);
        for k = 1:N
            if k == 1
                cluster_size = size(find(W==k));
            else            
                cluster_size = [cluster_size ; size(find(W==k))];
                if min(size(find(W==k))) == 0
                    break;
                end
            end
        end
        D_num = max(max(cluster_size));
    end

    W = cluster(Z,'maxclust', cul_num-1);
    for k = 1:N
        if k == 1
            cluster_size = size(find(W==k));
        else            
            cluster_size = [cluster_size ; size(find(W==k))];
            if min(size(find(W==k))) == 0
                break;
            end
        end
    end

    for k = 1:N
        if W(k) == find(cluster_size==max(max(cluster_size)))
            if D == 0
                D = k;
            else
                D = [D; k];
            end
        end
    end

    % BR    
    for k = 1:N
        for l = 1:N
            if S_check(k) == N
               BR(k,i) = NaN;
            else
                for m = 1:max(size(D))
                    if l == D(m)
                        BR(k,i) = BR(k,i) + SR(l,k);
                    end
                end
            end
        end
    end
    BR(:,i) = BR(:,i) ./ max(size(D));

    % CR
    CR = zeros(N,1);
    LTO_check = zeros(N,1);
    for k = 1:N
        for l = 1:N
            LTO_check(k) = LTO_check(k) + isnan(LTO(k,l));
        end
    end

    for k = 1:N
        Cr_deno = 0;
        Cr_nume = 0;
        if LTO_check(k) == N
            CR(k) = NaN;
        else
            for l = 1:N
                if isnan(LTO(k,l)) == 0                
                    Cr_nume = Cr_nume + ((LTO(k,l)-BR(l,i))^2);
                    Cr_deno = Cr_deno + 1;
                end            
            end
            CR(k) = 1-sqrt(Cr_nume/Cr_deno);
        end
    end

    % GR
    GR = zeros(N,1);
    for k = 1:N
        if isnan(BR(k,i)) == 1 && isnan(CR(k)) == 1
            GR(k) = NaN;
        elseif isnan(BR(k,i)) == 0 && isnan(CR(k)) == 0
            GR(k) = gamma*BR(k,i) + (1-gamma)*CR(k);
        elseif isnan(BR(k,i)) == 1 && isnan(CR(k)) == 0
            GR(k) = CR(k);
        else
            GR(k) = BR(k,i);
        end
    end

    % node decision
    for k = 1:N
        if isnan(GR(k)) == 1;
            node(k,i+2) = NaN;
        elseif GR(k) < decision;
            node(k,i+2) = 1;
        else
            node(k,i+2) = 0;
        end
    end
end
% Simulation result
FP = zeros(1,ttime/30);
FN = zeros(1,ttime/30);
TP = zeros(1,ttime/30);
f_hnode = ones(1,ttime/30)*(N-mnode);
f_mnode = ones(1,ttime/30)*mnode;                  % for result analysis

for k = 1:N
    for l = 1:(ttime/30)
        if isnan(node(k,l+2)) == 1
            if node(k,1) == 0
                f_hnode(l) = f_hnode(l) - 1;
            else
                f_mnode(l) = f_mnode(l) - 1;
            end
        elseif (node(k,1) == 0) && (node(k,l+2) == 1)
                FP(l) = FP(l) + 1;
        elseif (node(k,1) == 1) && (node(k,l+2) == 0)
                FN(l) = FN(l) + 1;
        elseif (node(k,1) == 1) && (node(k,l+2) == 1)            
                TP(l) = TP(l) + 1;
        end
    end
end
FP_prob = FP./f_hnode;
FN_prob = FN./f_mnode;
TP_prob = TP./f_mnode;

BR_temp = BR;
RMSE = zeros(1,ttime/30);
RMSE_deno = ones(1,ttime/30)*N;
for k = 1:(ttime/30)
    for l = 1:N
        if isnan(BR_temp(l,k)) == 0
            if node(l,1) == 0
                BR_temp(l,k) = BR_temp(l,k) - 1;
            else
                BR_temp(l,k) = BR_temp(l,k) - (1 - (alpha/2));
            end
        else
            RMSE_deno(k) = RMSE_deno(k) - 1;
            BR_temp(l,k) = 0;
        end
    end
end
RMSE = sqrt(sum(BR_temp.^2)./RMSE_deno);

