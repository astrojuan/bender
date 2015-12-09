#Compute image and make plots from raw image grid

#include("bender.jl")
#include("comp_img.jl")


p00 = plot2d(Times, x_grid, y_grid)
p11 = plot2d(Phis, x_grid, y_grid)
p21 = plot2d(Thetas, x_grid, y_grid)
p31 = plot2d(hits, x_grid, y_grid)

#interpolate into dense grid
print("interpolating into dense grid...")
#method = Gridded(Linear())
method = Gridded(Constant())
#extrapolate = BCnearest

Xrange = xmin:dx:xmax
Yrange = ymin:dy:ymax

Times = Times .- Times[ymid, xmid]    
time_interp    = interpolate((Yrange , Xrange), Times     ,method)
phi_interp_sin = interpolate((Yrange , Xrange), sin(Phis) ,method)
phi_interp_cos = interpolate((Yrange , Xrange), cos(Phis) ,method)
theta_interp   = interpolate((Yrange , Xrange), Thetas    ,method)
Xs_interp      = interpolate((Yrange , Xrange), Xs        ,method)
cosa_interp    = interpolate((Yrange , Xrange), cosas     ,method)
hits_interp    = interpolate((Yrange , Xrange), hits      ,method)


#wrapper for tan(phi) formalism
phi_interp_atan(y,x) = atan2(phi_interp_sin[y,x], phi_interp_cos[y,x])

Ny_dense = 500
Nx_dense = 500
Times_dense = zeros(Ny_dense, Nx_dense)
Phis_dense = zeros(Ny_dense, Nx_dense)
Thetas_dense = zeros(Ny_dense, Nx_dense)
hits_dense = zeros(Ny_dense, Nx_dense)
    
img = zeros(Ny_dense, Nx_dense)
img2 = zeros(Ny_dense, Nx_dense) #debug array
img3 = zeros(Ny_dense, Nx_dense) #debug array
img4 = zeros(Ny_dense, Nx_dense) #debug array
        
Flux = zeros(Ny_dense, Nx_dense)
Reds = zeros(Ny_dense, Nx_dense)

painter = chess_board

x_grid_d = linspace(xmin, xmax, Nx_dense)
y_grid_d = linspace(ymin, ymax, Ny_dense)

dx_d = abs(x_grid_d[2] - x_grid_d[1])
dy_d = abs(y_grid_d[2] - y_grid_d[1])


function radiation(Ir,
                   x,y,
                   phi, theta, cosa,
                   X, Xob, Osb, sini, earea)

    nu2   = beta/3.0 - quad*0.5*(3*cos(theta)^2-1)
    B2    = beta
    zeta2 = beta*(3*0.5*(3*cos(theta)^2-1)/4-1/3)
    Rgm, dR = Rgmf(theta, X, Osb)

    enu = (1-Xob/2)/(1+Xob/2)*exp(nu2*Xob^3)
    B = (1-Xob/2)*(1+Xob/2) + B2*Xob^2
    ezeta = (1-Xob/2)*(1+Xob/2) + zeta2*Xob^2

    C = (x^2 + y^2)
    Lz = x*sini
    w = wp*Xob^3*(1-3*Xob)

    fa = (B/enu/ezeta)*dR/Rgm
    
    cosg = 1/sqrt(1 + fa^2)
    sing = fa*cosg


    #if false
    ####
    #vphi = Rgm*(1/enu)*sin(theta)*(2pi*fs - w) #isoradial zamo
    #b = R*vphi/c
    #vw = Rgm*(1/enu)*sin(theta)*w #isoradial space vel
    #bp = R*vw/c
    #gamma = 1/sqrt(1 - b^2)
    #cosi = sqrt(1-sini^2)
    #sina = sqrt(1-cosa^2)
    #cospsi = cosi*cos(theta) + sini*sin(theta)*cos(phi)
    #cosz = -sina*sini*sin(phi)/sqrt(1-cospsi^2)
    #delta = (1/gamma)/(1 - b*cosz)
    #EEd = delta*enu*(1 + cosz*bp)
    #else

    
    vz = Rgm*(1/enu)*sin(theta)*(2pi*fs - w) #isoradial zamo
    bz = R*vz/c

    gamma = 1/sqrt(1-bz^2)
    delta = 1/gamma/(1 + Lz*(2pi*fs)/(G*M/c^2))
    EEd = delta*enu
    #end
    
    #dS = (Rgm)^2*sin(theta)*sqrt(1 + fa^2)
    cosap = cosa * delta
    #dOmega = dS*cosap
    
    dF = (EEd^3)*Ir(cosap) * earea #??? * delta
    #dF = (EEd^3)*dOmega*Ir(cosap)
    
    return dF, EEd
    #return gamma, gamma2
    #return dS, dOmega
end


#Image pizel size elements
#dxx = dx
#dyy = dy

dxx = 2.0*(x_grid_d[2] - x_grid_d[1])
dyy = 2.0*(y_grid_d[2] - y_grid_d[1])
dxdy = dxx*dyy #*X^2


#squares
function polyarea(x,y,dxx,dyy,phi0,the0;
                  exact=false)
    #image plane
    x1 = x - dxx/2
    x2 = x + dxx/2
    y1 = y - dyy/2
    y2 = y + dyy/2

    pts = [ (y1, x1), (y1, x2), (y2, x2), (y2, x1) ]
    
    if exact
        phis = Float64[]
        thetas = Float64[]
        for (yp, xp) in pts
            time, phi, theta, Xob, hit, cosa = bender3(xp, yp, sini,
                                                       X, Osb,
                                                       beta, quad, wp, Rg)
            if hit
                push!(phis, phi)
                push!(thetas, theta)
            end
        end
    else
        inside = filter(x -> hits_interp[x[1], x[2]] >= 1.0, pts)

        phis = map(x -> phi_interp_atan(x[1], x[2]), inside)
        thetas = map(x -> theta_interp[x[1], x[2]], inside)
    end
    
    if length(phis) < 3
        return 0.0
    end
    parea = area_sphere_lambert(phi0, the0, phis, thetas, Rq, ecc)
    
    return parea
end

#triangles
function polyarea2(x,y,dxx,dyy)
                              
    #image plane
    x1 = x - dxx
    x2 = x + dxx
    y1 = y - dyy/2
    y2 = y + dyy/2
            
    #surface
    phi1 = phi_interp_atan(y1, x1)
    phi2 = phi_interp_atan(y1, x2)
    phi3 = phi_interp_atan(y2, x)
    the1 = theta_interp[y1, x1]
    the2 = theta_interp[y1, x2]
    the3 = theta_interp[y2, x]
    
    parea = area_sphere_tri([phi1, phi2, phi3], [the1, the2, the3], Rq, ecc)
    return parea
end

#Get rough edge locations
x1s = zeros(Int, Ny)
x2s = zeros(Int, Ny)
y1s = 0
y2s = 0

top = false
for j = 1:Ny
    y = y_grid[j]

    left = false
    for i = 1:Nx
        x = x_grid[i]
        
        hit = hits[j,i]
        hiti = round(Int,hit - 0.45)

        if hiti == 1
            if left == false
                x1s[j] = i
                left = true
            else
                x2s[j] = i
            end

            if top == false
                y1s = j
                top = true
            else
                y2s = j
            end
        end
    end
end

println()
println("size (isotropic)")
println("xmin=",x_grid[minimum(x1s[y1s:y2s])]," xmax=",x_grid[maximum(x2s[y1s:y2s])])
println("ymin=",y_grid[y1s]," ymax=",y_grid[y2s])

xmin_edge = x_grid[minimum(x1s[y1s:y2s])-1]
xmax_edge = x_grid[maximum(x2s[y1s:y2s])+1]
ymin_edge = y_grid[y1s-1]
ymax_edge = y_grid[y2s+1]

rstar_min = min(abs(xmin_edge), abs(xmax_edge), abs(ymin_edge), abs(ymax_edge))
rstar_max = max(abs(xmin_edge), abs(xmax_edge), abs(ymin_edge), abs(ymax_edge))


tic()
##############################
for j = 1:Ny_dense    
    y = y_grid_d[j]

    if !(ymin_edge < y < ymax_edge)
        continue
    end
    
    for i = 1:Nx_dense
        x = x_grid_d[i]

        if !(xmin_edge < x < xmax_edge)
            continue
        end
        
        #println("x=$x y=$y")
        
        #interpolate if we are not on the edge or near the zipper
        #ring = rstar_min*0.99 < sqrt(x^2 + y^2) < 1.01*rstar_max
        #zipper = abs(x) < 0.1 && y > 3.0
        ring = false
        zipper = false
                    
        if ring || zipper
            time, phi, theta, Xob, hit, cosa = bender3(x, y, sini,
                                                       X, Osb,
                                                       beta, quad, wp, Rg)
        else
            # phi & theta
            phi = phi_interp_atan(y,x)
            theta = theta_interp[y,x]
            Xob = Xs_interp[y,x]
            time = time_interp[y,x]
            cosa = cosa_interp[y,x]
        
            #test if we hit the surface
            hit = hits_interp[y,x]
        end

        hiti = round(Int,hit - 0.49)

        
        if hiti > 0
            #solid angle
            ####
            
            earea = polyarea(x,y,dxx,dyy,phi,theta,
                             exact=(ring || zipper)
                             )

            
            Phis_dense[j,i] = phi
            Thetas_dense[j,i] = theta
            Times_dense[j,i] = time
            
            #chess board
            img[j,i] = painter(phi, theta)
                    
            #mu = sqrt(1-sini^2)*cos(theta) + sini*sin(theta)*cos(phi)
            #img2[j,i] = mu

            #radiation
            #cosa = cosa_interp[y,x]

            #if 0 < cosa < 1

            nu2   = beta/3.0 - quad*0.5*(3*cos(theta)^2-1)
            B2    = beta
            zeta2 = beta*(3*0.5*(3*cos(theta)^2-1)/4-1/3)
        
            Rgm, dR = Rgmf(theta, X, Osb)
            #cosa = cosalpha(x, y, sini, Rgm, dR,
            #                X/Rgm, nu2, B2, zeta2, wp, theta, Rg)

                
            img2[j,i] = cosa


            ##################################
            ##################################
            #approximative cosa test
            #if false
            if true        

                nu2   = beta/3.0 - quad*0.5*(3*cos(theta)^2-1)
                B2    = beta
                zeta2 = beta*(3*0.5*(3*cos(theta)^2-1)/4-1/3)
                Rgm, dR = Rgmf(theta, X, Osb)
                #Xob = X/Rgm
                
                enu = (1-Xob/2)/(1+Xob/2)*exp(nu2*Xob^3)
                B = (1-Xob/2)*(1+Xob/2) + B2*Xob^2
                ezeta = (1-Xob/2)*(1+Xob/2) + zeta2*Xob^2
                
                w = wp*Xob^3*(1-3*Xob)*G*M/c^2
                
                vphi = Rgm*(1/enu)*sin(theta)*(2pi*fs - w) #isoradial zamo
                b = R*vphi/c
                
                #vw = Rgm*B*(1/enu^2)*sin(theta)*w #isotropic space vel WRONG
                vw = Rgm*(1/enu)*sin(theta)*w #isoradial space vel
                bp = R*vw/c
                
                gamma = 1/sqrt(1 - b^2)
                cosi = sqrt(1-sini^2)
                sina = sqrt(1-cosa^2)
                cospsi = cosi*cos(theta) + sini*sin(theta)*cos(phi)
                cosz = -sina*sini*sin(phi)/sqrt(1-cospsi^2)
                
                ut = U/Rgm
                #xt = X/Rgm
                
                sqrta(xxx) = sqrt(abs(xxx))
                #cospsi = sqrt(1-sini^2)*cos(theta)+sini*sin(theta)*cos(phi)
                #cosaa = 1- (1-cospsi)*(1-Xob/2)/(1+Xob/2)*exp(nu2*(Xob)^3)
                #cosaa = 1 - (1-cospsi)*(1-ut)
                
                img4[j,i] = 1 - (1-cospsi)*(enu^2)#non-rotating reference approx
            
                cosaa = 1 - (1-cospsi)*(enu^2)/(1+cosz*bp)^3 #*(1-bp^2)^2
                #cosaa = 1 - (1-cospsi)*(enu^2)/(1+cosz*bp)^2.0 /((1-bp^2)^2)
                #cosaa = 1 - (1-cospsi)*(enu^2)*(1 + cosz*bp)^2 #Sul
                
                #cosaa = 1 - (1-cospsi)*(enu^2)/(1+cosz*(b+bp))^2 #/((1-bp^2)/(1+bp*b))^2
                
                #initially ingoing photons
                #bimpact = Rgm*sqrta(1-cosaa^2)/sqrta(1-ut)
                #bimpact = Rgm*sqrta(1-cosaa^2)/( (1-xt/2)/(1+xt/2) )
                #if bimpact < Rgm/sqrta(1-ut) && acos(cosaa) > pi/2
                
                #    rcsqrt = -(-9*bimpact^2*Rgm*ut + sqrta(12*bimpact^6 - 81*bimpact^4*Rgm^2*ut^2))
                #    rc = -(-2*3^(1/3)*bimpact^2 + 2^(1/3)*rcsqrt^(2/3))/(6^(2/3)*rcsqrt^(1/3))
                #    dspi = sqrta(2/rc)*sqrta(Rgm-rc)/sqrta(1-ut*(Rgm/rc))
                #    ocosaa = cosaa
                #    cosaa = cos(dspi + acos(ocosaa))
                #cosaa = -10.0
            #end

                #Change from spherical system to oblate according to Morsink et al 2007
                fa = (1/sqrt(1-ut))*dR/Rgm
                #cf = dR/Rgm
                cosg = 1/sqrt(1 + fa^2)
                sing = fa*cosg

                #cosg=0.5
                #sing=0.5
            
                #sing = sqrt(1-cosg^2)
                cosd = (sqrt(1-sini^2)-cos(theta)*cospsi)/(sin(theta)*sqrt(1-cospsi^2))
                if abs(sin(phi)) < 1.0e-4
                    cosb = cosaa*cosg
                else
                    cosb = cosaa*cosg + sqrta(1-cosaa^2)*sing*cosd
                end
                #cosb = clamp(cosb, 0.,1.)
                
                #img3[j,i] = cosb
                #img3[j,i] = fa    
                #img3[j,i] = cosaa
                #img3[j,i] = cosz
                #img3[j,i] = cosz*bp
            end #if false/true for cosa

            #img3[j,i] = time    
            img3[j,i] = earea

            #if earea == 0
            #    println("x=$x y=$y")
            #end
            # Solid angle
        
            
            ##################################
            ##################################

            #Radiation
            #Ir(cosa) = 1.0 #isotropic beaming
            Ir(cosa) = cosa
            
            dF, dE = radiation(Ir,
                               x,y,
                               phi, theta, cosa,
                               X, Xob, Osb, sini, earea)

            #if 0.79 < dE < 0.81
            #if dE < 0.79 || dE > 0.81
            Flux[j,i] = dF
            Reds[j,i] = dE
            end#hiti
        #end#cosa
    end
end

#Interpolate flux and redshift
Xrange_d = xmin:dx_d:xmax
Yrange_d = ymin:dy_d:ymax

flux_interp    = interpolate((Yrange_d , Xrange_d), Flux, method)
reds_interp    = interpolate((Yrange_d , Xrange_d), Reds, method)

toc()#end of interpolation into dense grid


#Make plots
p0 = plot2d(Times_dense, x_grid_d, y_grid_d, 0,0,10.0,"Blues")
p1 = plot2d(Phis_dense, x_grid_d, y_grid_d)
p2 = plot2d(Thetas_dense, x_grid_d, y_grid_d)
p3 = plot2d(img, x_grid_d, y_grid_d)

p4 = plot2d(img2, x_grid_d, y_grid_d, 0, 0, 0, "Blues")
p5 = plot2d(img3 ./ dxdy, x_grid_d, y_grid_d, 0, 0.0, 2.0, "Blues")

p6 = plot(y_grid_d, img2[:, round(Int,Ny_dense/2)+1],"k-", yrange=[-0.1, 1.1])
p6 = oplot(y_grid_d, img3[:,round(Int,Ny_dense/2)+1], "r--")
p6 = oplot(x_grid_d, img2[round(Int,Nx_dense/2)+1,:], "b-")
p6 = oplot(x_grid_d, img3[round(Int,Nx_dense/2)+1,:], "r--")

rel_err(x1,x2) = (x1 .- x2) ./ x1
xslice = round(Int,Nx_dense/2)+1
yslice = round(Int,Ny_dense/2)+1

p6e = plot(y_grid_d, rel_err(img2[:,xslice],img3[:,xslice]), "k-",yrange=[-0.05, 0.05])
p6e = oplot(y_grid_d, rel_err(img2[yslice,:],img3[yslice,:]), "b-")
p6e = oplot(y_grid_d, rel_err(img2[yslice,:],img4[yslice,:]), "g", linestyle="dotted")

p6e = oplot(y_grid_d, zeros(length(y_grid_d)), "k",linestyle="dotted")
p6e = oplot(y_grid_d, img2[:,xslice]*0.02, "k",linestyle="solid")
p6e = oplot(y_grid_d, img2[yslice,:]*0.02, "k",linestyle="solid")
p6e = oplot(y_grid_d, img3[:,xslice]*0.02, "r",linestyle="dashed")
p6e = oplot(y_grid_d, img3[yslice,:]*0.02, "m",linestyle="dashed")

p6e2 = plot(img2[:,xslice], rel_err(img2[:,xslice],img3[:,xslice]), "k-",yrange=[-0.6, 0.3])
p6e2 = oplot(img2[:,xslice], rel_err(img2[yslice,:],img3[yslice,:]), "b-")
p6e2 = oplot(img2[:,xslice], rel_err(img2[yslice,:],img4[yslice,:]), "g",linestyle="dotted")
p6e2 = oplot(img2[:,xslice], zeros(length(y_grid_d)), "k",linestyle="dotted")

#p6e2 = plot2d(rel_err(img2,img3), x_grid_d, y_grid_d, 0,0,0,"Blues")

#p7 = plot2d(Flux, x_grid_d, y_grid_d, 0,0,0, "RdBu")
#p8 = plot2d(Reds, x_grid_d, y_grid_d, 0,0,0, "RdBu")
p7 = plot2d(Flux ./ dxdy, x_grid_d, y_grid_d, 0,0,1.0, "Blues")
p8 = plot2d(Reds, x_grid_d, y_grid_d, 0,0,1.0, "Blues")


#####
# line profile
function line_prof(Flux, Reds)
    println("Computing line profile...")
    #for energ = linspace(1-0.01, 1+0.01, 40)

    xarr = Float64[]
    yarr = Float64[]

    Ny_dense, Nx_dense = size(Flux)
    
    energ = 1.0
    for jj = 1:Ny_dense, ii = 1:Nx_dense
        fy =  Flux[jj, ii]
        xii = Reds[jj, ii]
        
        if xii > 0
            push!(xarr, xii*energ)
            push!(yarr, fy)
        end
    end
    #end
    
    xind = sortperm(xarr)
    xarrs = xarr[xind]
    yarrs = yarr[xind]
    NN = length(xarrs)
    
    emin = minimum(xarrs)
    emax = maximum(xarrs)
    println("emin=$emin emax=$emax")
    Nr = 70
    es = collect(linspace(emin, emax, Nr))
    yy2 = zeros(Nr)
    
    xst = 1
    for ii = 2:Nr
        for jj = xst:NN
            if es[ii-1] <= xarrs[jj] < es[ii]
                yy2[ii] += yarrs[jj]
            elseif xarrs[jj] >= es[ii]
                xst = jj
                break
            end
        end
    end
    
    yy2 = yy2./maximum(yy2)
    #add start and end points to make smooth figure
    unshift!(es, es[1])
    unshift!(yy2, 0.0)
    push!(es, es[end])
    push!(yy2, 0.0)

    return es, yy2
end

es, yy2 = line_prof(Flux, Reds)
p9 = plot(es, yy2, "k-")
          #xlabel="E/E_0",
          #ylabel="Flux (arb)")
          #xrange=[0.7, 0.9])


#collect into table
tY = 3
tX = 4
table = Table(tY,tX)
images = [p0,p1,p2,p3,p4,p5,p6,p7,p8,p9]
imc = 1
for tty = 1:tY
    for ttx = 1:tX
        table[tty,ttx] = images[imc]
        imc += 1

        if imc > length(images)
            break
        end
    end
end
display(table)


#locate star edges for integration limits
println("Computing waveform...")
tic()

x1s = zeros(Int, Ny_dense)
x2s = zeros(Int, Ny_dense)
y1s = 0
y2s = 0

top = false
for j = 1:Ny_dense
    y = y_grid_d[j]

    left = false
    for i = 1:Nx_dense
        x = x_grid_d[i]
        
        hit = hits_interp[y,x]
        hiti = round(Int,hit - 0.45)

        if hiti == 1
            if left == false
                x1s[j] = i
                left = true
            else
                x2s[j] = i
            end

            if top == false
                y1s = j
                top = true
            else
                y2s = j
            end
        end
    end
end

println()
println("size (isotropic)")
println("xmin=",x_grid_d[minimum(x1s[y1s:y2s])]," xmax=",x_grid_d[maximum(x2s[y1s:y2s])])
println("ymin=",y_grid_d[y1s]," ymax=",y_grid_d[y2s])


Xob = Xs_interp[0,0]
#enu = (1-Xob/2)/(1+Xob/2)
#B=(1-Xob/2)*(1+Xob/2)
nu2   = beta/3.0 - quad*0.5*(-1.0)
B2    = beta
enu = (1-Xob/2)/(1+Xob/2)*exp(nu2*Xob^3)
B = (1-Xob/2)*(1+Xob/2) + B2*Xob^2
corr = enu/B

println()
println("size (isoradial)")
println("xmin=",x_grid_d[minimum(x1s[y1s:y2s])]*corr," xmax=",x_grid_d[maximum(x2s[y1s:y2s])]*corr)
println("ymin=",y_grid_d[y1s]*corr," ymax=",y_grid_d[y2s]*corr)

