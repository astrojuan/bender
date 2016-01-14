#Compute spot on the NS


#Load photon bender
#include("bender.jl")

#Compute raw image
#include("comp_img.jl")

#Interpolate from raw image and compute radiation processes
#include("radiation.jl")

rho = deg2rad(30.0)
colat = deg2rad(50.0)


########
function spot(t, phi, theta;
              stheta = deg2rad(50.0), #spot latitude
              delta = deg2rad(30.0) #spot half-opening angle
              )

    #Vincenty's formula
    d = great_circle_dist(0.0, phi, stheta, theta)
    
    if abs(d) < delta
        return true
    end
    
    return false
end


#photon time lag function
# returns new time-array index taking into account time delay effect
function time_lag(t, k, times, Nt, tbin, phi, theta)

    #exact from raytracing
    #dt = t/c
    #dt = t*G*M/c^3
    
    #approximative
    cosi = sqrt(1-sini^2)
    cospsi = cosi*cos(theta) + sini*sin(theta)*cos(phi)
    y = 1 - cospsi

    dt0 = y*R/c
    dt2 = y*(1.0 + (U*y/8.0)*(1+ y*(1.0/3.0 - U/14.0)))*R/c
    #println("dt: $dt  dt0: $dt0  dt2: $dt2 ")
    #println(" $(dt01/dt) ")

    #get new timebin index
    kd = 1
    while dt2 > (2kd - 1)*tbin
        kd += 1
    end
    kd -= 1

    kindx = k + kd
    if kindx > Nt; kindx -= Nt; end
    #while kindx > Nt
    #    kindx -= Nt
    #end

    
    #println("k: $k kd: $kd kindx: $kindx")
    #println()
    
    return kindx
end




img4 = zeros(Ny_dense, Nx_dense) #debug array

#Spot image frame size
N_frame = 50


#Beaming function for the radiation
#Ir(cosa) = 1.0 #isotropic beaming
Ir(cosa) = cosa

#Time parameters
Nt = 64
times = collect(linspace(0, 1/fs, Nt))
tbin = abs(times[2] - times[1])/2.0 
phase = collect(times .* fs)

spot_flux = zeros(Nt)
spot_flux2 = zeros(Nt)

sdelta = zeros(Nt)
sdelta2 = zeros(Nt)

sfluxE = zeros(Nt, 3)
sfluxNE = zeros(Nt, 3)

sfluxB = zeros(Nt)
sfluxNB = zeros(Nt)

#Polar integration

#create thick radius grid
Nrad_frame = 1000
rad_diffs = 1 ./ exp(linspace(0.0, 1.5, Nrad_frame-1).^2)
rad_grid_d = rmax * cumsum(rad_diffs) / sum(rad_diffs)
unshift!(rad_grid_d, 0.0)

tic()
#for k = 1:Nt
for k = 2:1
    t = times[k]

    radmin = 0.0
    radmax = 10.0
    chimin = 0.0
    chimax = 2pi
    
    for i = 2:Nchi-1
        chi = chi_grid[i]

        #avoid double integrating angle edges
        if chi < 0; continue; end
        if chi > 2pi; continue; end
        
        #if mod(i,10) == 0; println("chi: $(round(chi/2pi,2))"); end
    
        for j = 2:Nrad-1
            rad = rad_grid[j]

            if hits[j, i] < 1; break; end

    
            #Ray traced photons
            ####
            phi = Phis[j, i]
            theta = Thetas[j, i]

            #rotate star
            phi = phi - t*fs*2*pi
            phi = mod2pi(phi)

            inside = spot(0.0, phi, theta,
                          stheta = colat,
                          delta = rho
                          )

            if inside
                #println("inside")
                radmin = rad > radmin ? rad : radmin
                radmax = rad < radmax ? rad : radmax
                                 
                #time = Times[j, i]
                #Xob = Xs[j, i]
                #cosa = cosas[j, i]
                #dF = dFlux[j, i]
                #dE = Reds[j, i]

                #kd = time_lag(time, k, times, Nt, tbin, phi, theta)

                #drdchi = abs(rad_grid[j+1] - rad_grid[j-1])*abs(chi_grid[i+1] - chi_grid[i-1])*rad_grid[j]
                #spot_flux2[kd] += dF * drdchi
            end#inside
        end#rad
    end#chi


    #Integrate in thick interpolated grid
    println("radmin: $radmin radmax: $radmax")

       
    for i = 2:Nchi-1
        chi = chi_grid[i]

        #avoid double integrating angle edges
        if chi < 0; continue; end
        if chi > 2pi; continue; end
        
        for j = 2:Nrad_frame-1
        #j = 2
        #while j <= Nrad_frame-1    
            rad = rad_grid_d[j]

            #if rad < radmin; continue; end
            #if rad > radmax; j = Nrad_frame; end
            
            
            if hits_interp[rad, chi] < 1; break; end

            phi = phi_interp_atan(rad, chi)
            theta = theta_interp[rad, chi]
            
            #rotate star
            phi = phi - t*fs*2*pi
            phi = mod2pi(phi)
            
            inside = spot(0.0, phi, theta,
                          stheta = colat,
                          delta = rho
                          )

            #println("spot")
            
            if inside
                #println("inside")
                time = time_interp[rad, chi]
                Xob = Xs_interp[rad, chi]
                cosa = cosa_interp[rad, chi]
                dF = flux_interp[rad, chi]
                dE = reds_interp[rad, chi]

                kd = time_lag(time, k, times, Nt, tbin, phi, theta)

                drdchi = abs(rad_grid_d[j+1] - rad_grid_d[j-1])*abs(chi_grid[i+1] - chi_grid[i-1])*rad_grid_d[j]
                spot_flux2[kd] += dF * drdchi
            end#inside

            #j += 1
        end
    end

    
    println("time = $t")
    p10polar = plot(phase, spot_flux2, "k-")
    p10polar = oplot([phase[k]], [spot_flux2[k]], "ko")
    display(p10polar)
    
end#time
toc()


#Cartesian integration
#########

tic()

for k = 1:Nt
#for k = 20:20
#for k = 27:26
#for k = 80:80
#for k = 24:38
#for k = 20:45
        
    img4[:,:] = 0.0
    
    t = times[k]
    println()
    println("t: $t k: $k")
    
    #set whole image as starting frame
    frame_y2 = y_grid_d[1]
    frame_y1 = y_grid_d[end]
    frame_x1 = x_grid_d[end]
    frame_x2 = x_grid_d[1]

    #inf_small = true
    
    for j = y1s:y2s
        y = y_grid_d[j]

        #frame_left = false
        
        for i = x1s[j]:x2s[j]
            x = x_grid_d[i]

            rad = hypot(x,y)
            chi = mod2pi(pi/2 - atan2(y,x))
            
            #trace back to star
            phi = phi_interp_atan(rad,chi)
            theta = theta_interp[rad,chi]
                        
            #rotate star
            phi = phi - t*fs*2*pi
            phi = mod2pi(phi)
      
            img4[j,i] = painter(phi, theta)/2.0

            inside = spot(0.0, phi, theta,
                          stheta = colat,
                          delta = rho
                          )
            
            if inside
            #if inside && inf_small
            #    inf_small = false
                
                #track down spot edges

                #println("x = $x y = $y")
                frame_y2 = frame_y2 < y ? y : frame_y2 #top #max
                frame_y1 = frame_y1 > y ? y : frame_y1 #bottom #min
                frame_x1 = frame_x1 > x ? x : frame_x1 #left min
                frame_x2 = frame_x2 < x ? x : frame_x2 #right max

                #println(frame_x1)
                #println(frame_x2)
                #println(frame_y1)
                #println(frame_y2)
                #println()
                 
                #Time shifts for differnt parts
                time = time_interp[rad,chi]
                cosa = cosa_interp[rad,chi]
                kd = time_lag(time, k, times, Nt, tbin, phi, theta)
    
                #Xob = Xs_interp[y,x] 
                #cosa = cosa_interp[y,x]
                #dF, dE = radiation(Ir,
                #                   x,y,
                #                   phi, theta, cosa,
                #                   X, Xob, Osb, sini, img3[j,i])
                #dF = flux_interp[y,x]
                #dE = reds_interp[y,x]
                delta = delta_interp[rad,chi]
                EEd = reds_interp[rad,chi]
                    
                dfluxE, dfluxNE, dfluxNB, dfluxB = bbfluxes(EEd, delta, cosa)
                    
                #img4[j,i] = painter(phi, theta)
                    
                #img5[j,i] += 1.0e9*dF * frame_dxdy
                #println(dF)

                #println(dfluxB)
                #img4[j,i] += dfluxB * dxdy * imgscale*1.0e7
                img4[j,i] += EEd * dxdy * imgscale /1.0e5
                
                #println(img4[j,i])
                #dF = flux_interp[rad,chi]
                #dE = reds_interp[rad,chi]
                                                
                #img4[j,i] = painter(phi, theta)
                #img4[j,i] += 3.0*dF*dxdy
                #img4[j,i] = 5.0

                #zipper = abs(x) < 0.18 && y > 4.67
                #if !zipper
                #spot_flux[kd] += dF
                
                #spot_flux[k] += dF
                #end
            end #if inside            

            

        end# for x
    end#for y

    #continue
    
    #TODO: deal with hidden spot
    #i.e. skip time bin

    
    #expand image a bit
    #########
    frame_expansion_x = abs(x_grid_d[4] - x_grid_d[1])
    frame_expansion_y = abs(y_grid_d[4] - y_grid_d[1])
    frame_y2 += frame_expansion_y
    frame_y1 -= frame_expansion_y
    frame_x1 -= frame_expansion_x
    frame_x2 += frame_expansion_x

    #Exapand image a bit keeping the aspect ratio
    ##########
    #frame_expansion_x = abs(frame_x2 - frame_x1)
    #frame_expansion_y = abs(frame_y2 - frame_y1)

    #frame_y1 -= frame_expansion_y*0.02
    #frame_y2 += frame_expansion_y*0.02
    #frame_x1 -= frame_expansion_x*0.02
    #frame_x2 += frame_expansion_x*0.02

    frame_xs = abs(frame_x2 - frame_x1)/N_frame
    frame_ys = abs(frame_y2 - frame_y1)/N_frame


    println("x1: $frame_x1  x2: $frame_x2  y1: $frame_y1 y2: $frame_y2")  
    println("x = $frame_xs y = $frame_ys")

    #pick smaller
    #if frame_xs > frame_ys
    #    Nx_frame = N_frame
    #    Ny_frame = max(round(Int, (frame_ys*N_frame/frame_xs)), 2)
    #else
    #    Ny_frame = N_frame
    #    Nx_frame = max(round(Int, (frame_xs*N_frame/frame_ys)), 2)
    #end

    #select larger
    #if frame_xs < frame_ys
    #    Nx_frame = N_frame
    #    Ny_frame = max(round(Int, (frame_ys*N_frame/frame_xs)), 2)
    #else
    #    Ny_frame = N_frame
    #    Nx_frame = max(round(Int, (frame_xs*N_frame/frame_ys)), 2)
    #end

    #keep aspect ratio
    if frame_xs < frame_ys
        Nx_frame = max(round(Int, (frame_ys*N_frame/frame_xs)), 2)
        Ny_frame = max(round(Int, (frame_ys*N_frame/frame_xs)), 2)
    else
        Ny_frame = max(round(Int, (frame_xs*N_frame/frame_ys)), 2)
        Nx_frame = max(round(Int, (frame_xs*N_frame/frame_ys)), 2)
    end

    

    println("Nx= $Nx_frame Ny = $Ny_frame")
    
    frame_xgrid = collect(linspace(frame_x1, frame_x2, Nx_frame))
    frame_ygrid = collect(linspace(frame_y1, frame_y2, Ny_frame))
    frame_dxx = 1.0*(frame_xgrid[2] - frame_xgrid[1])
    frame_dyy = 1.0*(frame_ygrid[2] - frame_ygrid[1])
    frame_dxdy = frame_dxx*frame_dyy #*X^2

    #Locate spot edges on the old grid
    ##########
    
    #Plot large image with bounding box for the spot
    p10a = plot2d(img4, x_grid_d, y_grid_d, 0, 0, 2, "Blues")
    Winston.add(p10a, Curve([frame_x1, frame_x2, frame_x2, frame_x1, frame_x1],
                           [frame_y1, frame_y1, frame_y2, frame_y2, frame_y1],
                           linestyle="solid"))
    #add time stamp
    xs = x_grid_d[1] + 0.84*(x_grid_d[end] - x_grid_d[1])
    ys = y_grid_d[1] + 0.93*(y_grid_d[end] - y_grid_d[1])
    Winston.add(p10a, Winston.DataLabel(xs, ys, "$(k) ($(round(times[k]*fs,3)))"))
    #display(p10)

    #println("dx = $(frame_dxx) dy = $(frame_dyy)")


    
    #Integrate flux inside of the spot image frames
    
    #img5[:,:] = 0.0
    img5 = zeros(Ny_frame, Nx_frame) #debug array

    Ndelta = 0

    for j = 1:Ny_frame
        y = frame_ygrid[j]
        for i = 1:Nx_frame
            x = frame_xgrid[i]

            rad = hypot(x,y)
            chi = mod2pi(pi/2 - atan2(y,x))

            #interpolate if we are not on the edge or near the zipper
            #ring = rstar_min*0.98 < sqrt(x^2 + y^2) < 1.01*rstar_max
            #zipper = abs(x) < 0.1 && y > 3.0
            ring = false
            zipper = false
            #ring = true
            #zipper = true

            
            if ring || zipper
                time, phi, theta, Xob, hit, cosa = bender3(x, y, sini,
                                                           X, Osb,
                                                           beta, quad, wp, Rg)
            else
                # phi & theta
                phi = phi_interp_atan(rad,chi)
                theta = theta_interp[rad,chi]
                Xob = Xs_interp[rad,chi]
                time = time_interp[rad,chi]
                cosa = cosa_interp[rad,chi]
                
                #test if we hit the surface
                hit = hits_interp[rad,chi]
            end

            #time, phi, theta, Xob, hit, cosa = bender3(x, y, sini,
            #                                           X, Osb,
            #                                           beta, quad, wp, Rg)

            #test if we hit the surface
            #hit = hits_interp[y,x]
            #hiti = round(Int,hit - 0.49)
            hiti = round(Int, hit)
            
            if hiti > 0
                #phi = phi_interp_atan(y,x)
                #theta = theta_interp[y,x]

                #rotatate star
                phi = phi - t*fs*2*pi
                phi = mod2pi(phi)
                
                img5[j,i] = painter(phi, theta)/2.0
                #if (ring || zipper)
                #    img5[j,i] = painter(phi, theta)/2.0
                #end

                
                inside = spot(0.0, phi, theta,
                              stheta = colat,
                              delta = rho
                              )

                if inside
                    #time = time_interp[y,x]

                    #compute 
                    #earea = polyarea(x, y,
                    #                 frame_dxx, frame_dyy,
                    #                 phi, theta,
                    #                 exact=(ring || zipper)
                    #                 #exact=true
                    #                 #exact=false
                    #                 )

                    kd = time_lag(time, k, times, Nt, tbin, phi, theta)

                    if kd != k
                        println("time shift")
                    end
                    
                    #Xob = Xs_interp[y,x] 
                    #cosa = cosa_interp[y,x]
                    #dF, dE = radiation(Ir,
                    #                   x,y,
                    #                   phi, theta, cosa,
                    #                   X, Xob, Osb, sini, earea)
                    
                    #dF = flux_interp[y,x]
                    #dE = reds_interp[y,x]

                    #dF = flux_interp[rad,chi]

                    delta = delta_interp[rad,chi]
                    EEd = reds_interp[rad,chi]
                    
                    dfluxE, dfluxNE, dfluxNB, dfluxB = bbfluxes(EEd, delta, cosa)
                    
                    #img4[j,i] = painter(phi, theta)
                    
                    #img5[j,i] += 1.0e9*dF * frame_dxdy
                    #println(dF)

                    #println(dfluxB)
                    sdelta[k] += delta
                    sdelta2[k] += EEd
                    Ndelta += 1
                    
                    img5[j,i] += dfluxB * frame_dxdy * imgscale * 1.0e3
                    
                    #img5[j,i] = 5.0
                    #if kd != k
                    #    println("dF: $dF $k $kd")
                    #end
                    #spot_flux[kd] += dF / frame_dxdy
                    #spot_flux[kd] += frame_dxdy
                    #spot_flux[k] += dF * frame_dxdy

                    for ie = 1:3
                        sfluxE[kd, ie] += dfluxE[ie] * frame_dxdy * imgscale
                        sfluxNE[kd, ie] += dfluxNE[ie] * frame_dxdy * imgscale
                    end
                    sfluxNB[kd] += dfluxNB * frame_dxdy * imgscale
                    sfluxB[kd] += dfluxB * frame_dxdy * imgscale
                end #inside spot
            end#hiti
        end #x
    end#y

    println("bol flux: $(sfluxB[k]) | num flux $(sfluxNB[k])")

    p10b = plot2d(img5, frame_xgrid, frame_ygrid, 0, 0, 2, "Blues")

    #add time stamp
    xs = frame_xgrid[1] + 0.84*(frame_xgrid[end]-frame_xgrid[1])
    ys = frame_ygrid[1] + 0.93*(frame_ygrid[end]-frame_ygrid[1])
    Winston.add(p10b, Winston.DataLabel(xs, ys, "$(k)"))
    #display(p10)

    #bol flux
    p10c = plot(phase, sfluxB, "k-")
    p10c = oplot([phase[k]], [sfluxB[k]], "ko")

    #doppler factor
    #p10c = plot(phase, (sdelta./Ndelta).^5, "b-")
    #p10c = oplot(phase, (sdelta2./Ndelta).^5, "r-")
    #p10c = plot(phase, (sdelta2./sdelta), "r-")
    #p10c = oplot([phase[k]], [sfluxB[k]], "ko")


    tt1 = Table(1,2)
    tt1[1,1] = p10a
    tt1[1,2] = p10b

    tt = Table(2,1)
    tt[1,1] = tt1
    tt[2,1] = p10c
    display(tt)

    #readline(STDIN)

end#for t
toc()


#write to file
opath = "out/"
mkpath(opath)


fname = "f$(round(Int,fs))_lamb_bb_R$(round(R/1e5,1))_M$(round(M/Msun,1))_rho$(round(Int,rad2deg(rho))).csv"
wmatr = zeros(Nt, 6)
wmatr[:,1] = phase
wmatr[:,2] = sfluxNE[:, 1] #2 kev
wmatr[:,3] = sfluxNE[:, 2] #6 kev
wmatr[:,4] = sfluxNE[:, 3] #12 kev
wmatr[:,5] = sfluxNB #bol number flux
wmatr[:,6] = sfluxB #bol energy flux

writecsv(opath*fname, wmatr)
