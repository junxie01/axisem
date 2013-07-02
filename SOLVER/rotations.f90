!-----------------------------------------------------------------------------
module rotations

  use global_parameters
  use data_mesh
  use data_source
  use data_io
  use data_proc
  
  implicit none
  
  public :: def_rot_matrix, rotate_receivers_recfile,save_google_earth_kml
  private

contains

!-----------------------------------------------------------------------------
subroutine def_rot_matrix

  real(kind=realkind), dimension (3,3)  :: mom_tensor
  real(kind=realkind), dimension(3)     :: single_force, rot_single_force
  integer :: i, j

  if (lpr) then
    write(6,*)
    write(6,*) '  Need to rotate the source to the north pole!'
    write(6,*) '  .... therefore computing rotation matrix and its transpose'
  endif
 
  ! This is the rotation matrix of Nissen-Meyer, Dahlen, Fournier, GJI 2007.
  rot_mat(1,1) = dcos(srccolat) * dcos(srclon)
  rot_mat(2,2) = dcos(srclon)
  rot_mat(3,3) = dcos(srccolat)
  rot_mat(2,1) = dcos(srccolat) * dsin(srclon)
  rot_mat(3,1) = -dsin(srccolat)
  rot_mat(3,2) = 0.d0
  rot_mat(1,2) = -dsin(srclon)
  rot_mat(1,3) = dsin(srccolat) * dcos(srclon)
  rot_mat(2,3) = dsin(srccolat) * dsin(srclon)

  do i=1,3
      do j=1,3
          if (dabs(rot_mat(i,j))<smallval) rot_mat(i,j)=0.d0
      enddo
  enddo

  trans_rot_mat = transpose(rot_mat)

  if ((trim(src_file_type) == 'sourceparams')) then 
    if (lpr) then
        write(6,*)'  WARNING: This means that your source radiation patterns are different!'
        write(6,*)'           .... to make sure the pattern is as desired, you will need to rotate'
        write(6,*)'           the source term a posteriori using the following formula:'

        if (src_type(2)=='mxy' .or. src_type(2)=='mxz' .or. src_type(2)=='myz' &
                .or. src_type(2)=='mxx_m_myy' ) then
            write(6,*)'           M_rot = matmul(transpose(R),matmul(M_0,R)), with:'
        else 
            write(6,*)'           p_rot = matmul(transpose(R),p_0), with:'
        endif

        write(6,*)
        write(6,*)  '           rotation matrix R='
        write(6,12) '           ', rot_mat(1,1), rot_mat(1,2), rot_mat(1,3)
        write(6,12) '           ', rot_mat(2,1), rot_mat(2,2), rot_mat(2,3)
        write(6,12) '           ', rot_mat(3,1), rot_mat(3,2), rot_mat(3,3)
    endif !lpr
  endif 

  mom_tensor(:,:) = 0.d0
  if (src_type(2) == 'mxy') then 
      mom_tensor(1,2) = magnitude
      mom_tensor(2,1) = magnitude
  elseif (src_type(2) == 'mxz') then 
      mom_tensor(1,3) = magnitude
      mom_tensor(3,1) = magnitude
  elseif (src_type(2) == 'myz') then 
      mom_tensor(2,3) = magnitude
      mom_tensor(3,2) = magnitude
  elseif (src_type(2)=='mxx_m_myy') then 
      mom_tensor(1,1) =  magnitude
      mom_tensor(2,2) = -magnitude
  elseif (src_type(2)=='mxx_p_myy') then 
      mom_tensor(1,1) = magnitude
      mom_tensor(2,2) = magnitude
  elseif (src_type(2)=='mzz') then 
      mom_tensor(3,3) = magnitude
  endif 

  single_force(:) = 0.d0
  if (src_type(2) == 'vertforce') single_force(3) = magnitude
  if (src_type(2) == 'xforce') single_force(1) = magnitude
  if (src_type(2) == 'yforce') single_force(2) = magnitude
  
  if ( maxval(abs(mom_tensor))>0.1*magnitude) then
      rot_mom_tensor = matmul(matmul(trans_rot_mat,mom_tensor),rot_mat)

      if (lpr) then
        write(6,*)
        write(6,*)'                        initial moment tensor M_0='
        write(6,12)'                        ',mom_tensor(1,1),mom_tensor(1,2),mom_tensor(1,3)
        write(6,12)'                        ',mom_tensor(2,1),mom_tensor(2,2),mom_tensor(2,3)
        write(6,12)'                        ',mom_tensor(3,1),mom_tensor(3,2),mom_tensor(3,3)
        write(6,*)
      end if

      ! Changing the source radiation pattern! Only if source is separate. CMT is not rotated.
      if (trim(src_file_type)=='sourceparams') then 
        if (lpr) write(6,*)'                        rotated moment tensor M_rot='
        if (lpr) write(6,12)'                        ',rot_mom_tensor(1,1),rot_mom_tensor(1,2),rot_mom_tensor(1,3)
        if (lpr) write(6,12)'                        ',rot_mom_tensor(2,1),rot_mom_tensor(2,2),rot_mom_tensor(2,3)
        if (lpr) write(6,12)'                        ',rot_mom_tensor(3,1),rot_mom_tensor(3,2),rot_mom_tensor(3,3)
        if (lpr) write(6,*)

      if (abs(abs(rot_mom_tensor(2,1))-magnitude)<smallval .and. rot_mom_tensor(3,1)==0.d0 .and. &
                  rot_mom_tensor(3,2)==0.d0 .and. rot_mom_tensor(1,1)==0.d0 .and. & 
                  rot_mom_tensor(2,2)==0.d0 .and. rot_mom_tensor(3,3)==0.d0 ) then 
          src_type(1)='quadpole'
          src_type(2)='mxy'
          if (rot_mom_tensor(2,1)<0.d0) magnitude=-magnitude ! negative value
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),'source instead!' 
          if (lpr) write(6,*)'                      Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)
  
      elseif (abs(abs(rot_mom_tensor(3,1))-magnitude)<smallval .and. rot_mom_tensor(2,1)==0.d0 .and. &
                  rot_mom_tensor(3,2)==0.d0 .and. rot_mom_tensor(1,1)==0.d0 .and. & 
                  rot_mom_tensor(2,2)==0.d0 .and. rot_mom_tensor(3,3)==0.d0 ) then 
          src_type(1)='dipole'
          src_type(2)='mxz'
          if (rot_mom_tensor(3,1)<0.d0) magnitude=-magnitude ! negative value
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),'source instead!' 
          if (lpr) write(6,*)'                       Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)
  
      elseif (abs(abs(rot_mom_tensor(3,2))-magnitude)<smallval .and. rot_mom_tensor(2,1)==0.d0 .and. &
                  rot_mom_tensor(3,1)==0.d0 .and. rot_mom_tensor(1,1)==0.d0 .and. & 
                  rot_mom_tensor(2,2)==0.d0 .and. rot_mom_tensor(3,3)==0.d0 ) then 
          src_type(1)='dipole'
          src_type(2)='myz'
          if (rot_mom_tensor(3,2)<0.d0) magnitude=-magnitude ! negative value
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),'source instead!' 
          if (lpr) write(6,*)'                      Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)
  
      elseif ( abs(rot_mom_tensor(1,1)+rot_mom_tensor(2,2))<smallval .and.  &
                  abs(abs(rot_mom_tensor(1,1))-magnitude)<smallval .and. rot_mom_tensor(2,1)==0.d0 .and. &
                  rot_mom_tensor(3,1)==0.d0 .and. rot_mom_tensor(3,2)==0.d0 .and. & 
                  rot_mom_tensor(3,3)==0.d0 ) then 
          src_type(1)='quadpole'
          src_type(2)='mxx_m_myy'
          if (rot_mom_tensor(1,1)<0.d0) magnitude=-magnitude ! negative value       
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),'source instead!' 
          if (lpr) write(6,*)'                      Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)
  
      elseif ( abs(rot_mom_tensor(1,1)-rot_mom_tensor(2,2))<smallval .and.  &
                  abs(abs(rot_mom_tensor(1,1))-magnitude)<smallval .and. rot_mom_tensor(2,1)==0.d0 .and. &
                  rot_mom_tensor(3,1)==0.d0 .and. rot_mom_tensor(3,2)==0.d0 .and. & 
                  rot_mom_tensor(3,3)==0.d0 ) then 
          src_type(1)='monopole'
          src_type(2)='mxx_p_myy'
          if (rot_mom_tensor(1,1)<0.d0) magnitude=-magnitude ! negative value       
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),magnitude,'source instead!' 
          if (lpr) write(6,*)'                           Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)
  
      elseif (abs(abs(rot_mom_tensor(3,3))-magnitude)<smallval .and. rot_mom_tensor(2,1)==0.d0 .and. &
                  rot_mom_tensor(3,1)==0.d0 .and. rot_mom_tensor(3,2)==0.d0 .and. & 
                  rot_mom_tensor(1,1)==0.d0 .and. rot_mom_tensor(2,2)==0.d0 ) then 
          src_type(1)='monopole'
          src_type(2)='mzz'
          if (rot_mom_tensor(3,3)<0.d0) magnitude=-magnitude ! negative value       
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),magnitude,'source instead!' 
          if (lpr) write(6,*)'                           Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)
  
      else
          if (lpr) write(6,*) &
               '                        ... which means additional simulations to account for new non-zero elements of M'
          if (lpr) write(6,*)
      endif
  
      if (lpr) write(6,*)'  Rotating moment tensor since given in cartesian components (sourceparams.dat)...'
      Mij(1)  = rot_mom_tensor(3,3) 
      Mij(2)  = rot_mom_tensor(1,1)
      Mij(3)  = rot_mom_tensor(2,2)
      Mij(4)  = rot_mom_tensor(1,3)
      Mij(5)  = rot_mom_tensor(2,3)
      Mij(6)  = rot_mom_tensor(1,2)

      endif !src_file_type==sourceparams
  elseif ( maxval(abs(single_force)) > 0.1*magnitude) then 
      rot_single_force = matmul(trans_rot_mat,single_force)
      if (lpr) then
          write(6,*)
          write(6,*)'                        initial single force p_0='
          write(6,11)'                        ',single_force(1)
          write(6,11)'                        ',single_force(2)
          write(6,11)'                        ',single_force(3)
          write(6,*)
          write(6,*)'                        rotated single force p_rot='
          write(6,11)'                        ',rot_single_force(1)
          write(6,11)'                        ',rot_single_force(2)
          write(6,11)'                        ',rot_single_force(3)
          write(6,*)
      endif ! lpr

      if (abs(abs(rot_single_force(1))-magnitude)<smallval .and. &
                  rot_single_force(2)==0.d0 .and. rot_single_force(3)==0.d0) then 
          src_type(1)='dipole'
          src_type(2)='xforce'
          if (rot_single_force(1)<0.d0) magnitude=-magnitude ! negative value       
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),magnitude,'source instead!' 
          if (lpr) write(6,*)'                           Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)           

      elseif (abs(abs(rot_single_force(2))-magnitude)<smallval .and. & 
                  rot_single_force(1)==0.d0 .and. rot_single_force(3)==0.d0) then 
          src_type(1)='dipole'
          src_type(2)='yforce'
          if (rot_single_force(2)<0.d0) magnitude=-magnitude ! negative value       
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),magnitude,'source instead!' 
          if (lpr) write(6,*)'                           Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)           

      elseif (abs(abs(rot_single_force(3))-magnitude)<smallval .and. & 
                  rot_single_force(1)==0.d0 .and. rot_single_force(2)==0.d0) then 
          src_type(1)='monopole'
          src_type(2)='vertforce'
          if (rot_single_force(3)<0.d0) magnitude=-magnitude ! negative value       
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  WARNING! Now computing a ',src_type(1),src_type(2),magnitude,'source instead!' 
          if (lpr) write(6,*)'                           Magnitude:',magnitude
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)'  <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>'
          if (lpr) write(6,*)           

      else
         write(6,*)'                        ... which means additional simulations to account for the other force components'
         write(6,*)
      endif

   endif

11 format(a25,1pe12.3)
12 format(a25,3(1pe12.3))

end subroutine def_rot_matrix
!=============================================================================

!-----------------------------------------------------------------------------
subroutine rotate_receivers_recfile(num_rec_glob, rcvcolat, rcvlon1, receiver_name)

  integer, intent(in)             :: num_rec_glob
  double precision, intent(inout) :: rcvcolat(1:num_rec_glob)
  double precision, intent(inout) :: rcvlon1(1:num_rec_glob)
  character(len=40), intent(in)   :: receiver_name(num_rec_glob)
  integer                         :: ircv
  double precision                :: x_vec(3), x_vec_rot(3), r_r
  double precision                :: rcvlon(1:num_rec_glob)

  if (lpr) write(6,*)'  Rotating receivers and source to pole-centered system...'
  if (lpr) &
  call save_google_earth_kml(real(srccolat*180.0/pi),real(srclon*180.0/pi), &
                                real(rcvcolat),real(rcvlon1),num_rec_glob,'original',receiver_name)

  rcvcolat=rcvcolat*pi/180.d0
  rcvlon=rcvlon1*pi/180.d0

  if (lpr) then 
     open(unit=37,file=infopath(1:lfinfo)//'/receiver_xyz_orig.dat')
     open(unit=38,file=infopath(1:lfinfo)//'/receiver_xyz_rot.dat')
     write(37,*)dsin(srccolat)*dcos(srclon),dsin(srccolat)*dsin(srclon),dcos(srccolat)
     write(38,*)0.d0,0.d0,1.d0
  endif
  do ircv=1,num_rec_glob

     x_vec(1)=dsin(rcvcolat(ircv))*dcos(rcvlon(ircv))
     x_vec(2)=dsin(rcvcolat(ircv))*dsin(rcvlon(ircv))
     x_vec(3)=dcos(rcvcolat(ircv))

     x_vec_rot=matmul(trans_rot_mat,x_vec)
     
     if (lpr) then
        write(37,*)x_vec(1),x_vec(2),x_vec(3)
        write(38,*)x_vec_rot(1),x_vec_rot(2),x_vec_rot(3)
     endif

     r_r = dsqrt(x_vec_rot(1)**2 + x_vec_rot(2)**2 + x_vec_rot(3)**2)
     rcvcolat(ircv) = dacos(x_vec_rot(3) / (r_r +smallval_dble))
     
     if (x_vec_rot(2) >= 0.) then
        rcvlon(ircv) = dacos(x_vec_rot(1) / (r_r * dsin(rcvcolat(ircv)) + smallval_dble))
     else
        rcvlon(ircv) = 2*pi - dacos(x_vec_rot(1) / (r_r * dsin(rcvcolat(ircv)) + smallval_dble))
     end if

     if (dabs(r_r-1.d0) > smallval) then 
        write(6,*)procstrg,'  Problem with radius of receiver location!!'
        write(6,*)procstrg,',  Receiver at:',rcvcolat(ircv)*180./pi,rcvlon(ircv)
     endif

  enddo
  
  if (lpr) close(37)
  if (lpr) close(38)

  rcvcolat=rcvcolat*180.d0/pi
  rcvlon=rcvlon*180.d0/pi
  rcvlon1=rcvlon

  if (lpr) &
  call save_google_earth_kml(0.0,0.0,real(rcvcolat),real(rcvlon),num_rec_glob,'rotated_',receiver_name)

  if (lpr) then
     open(99991,file=datapath(1:lfdata)//'/receiver_rotated.dat')
     do ircv=1,num_rec_glob
        write(99991,*)rcvcolat(ircv),rcvlon(ircv)
     enddo
     close(99991)
  endif



end subroutine rotate_receivers_recfile
!=============================================================================

!-----------------------------------------------------------------------------
subroutine save_google_earth_kml(srccolat1, srclon1, rcvcolat, rcvlon, &
                                 num_rec_glob, fname, receiver_name)

  use data_proc, only : appmynum
  
  integer, intent(in)           :: num_rec_glob
  real, intent(in)              :: srccolat1, srclon1, rcvcolat(1:num_rec_glob), &
                                   rcvlon(1:num_rec_glob)
  character(len=40), intent(in) :: receiver_name(num_rec_glob)
  character(len=8), intent(in)  :: fname
  real              :: slon,slat,rlon(1:num_rec_glob),rlat(1:num_rec_glob)
  integer           :: i
  character(len=4)  :: app
  character(len=2)  :: comp(3)
  
  slat=90.-srccolat1
  slon=srclon1
  if (slon>180.) slon=slon-360.
  
  rlat=90.-rcvcolat
  rlon=rcvlon
  do i=1,num_rec_glob
     if (rlon(i)>180.) rlon(i)=rlon(i)-360.
  enddo
  
  ! components
  comp(1) = 's'
  comp(2) = 'ph'
  comp(3) = 'z'
   
  open(unit=88,file=infopath(1:lfinfo)//'/src_rec_'//fname//'.kml')
  
  write(88,14)'<?xml version="1.0" encoding="UTF-8"?> '
  write(88,15)'<kml xmlns="http://earth.google.com/kml/2.0"> '
  write(88,16)'<Document> '
  
  write(88,*)
  write(88,*)'  <name> ',trim(fname),' earthquake-receiver configuration</name>'
  write(88,*)'    <LookAt>'
  write(88,12)'     <longitude>',slon,'</longitude><latitude>',slat,'</latitude>'
  write(88,*)'     <range>7000000</range><tilt>0</tilt><heading>0</heading>'
  write(88,*)'    </LookAt>'
  write(88,*)
  write(88,*)'......'
  write(88,*)'  <Placemark>'
  write(88,*)'     <Style id="earthquake">'
  write(88,*)'       <IconStyle>'
  write(88,*)'       <scale>5</scale>'
  write(88,*)'         <Icon>'
  if (fname=='original') then
     write(88,*)' <href>http://maps.google.com/mapfiles/kml/shapes/earthquake.png</href>'
  else
     write(88,*)' <href>http://maps.google.com/mapfiles/kml/shapes/volcano.png</href>'
  endif
  write(88,*)'             </Icon>'
  write(88,*)'           </IconStyle>'
  write(88,*)'                  <LabelStyle>'
  write(88,*)'                      <scale>5</scale>'
   write(88,*)'                 </LabelStyle>'
  write(88,*)'        </Style>'
  write(88,*)'    <name>',fname,' earthquake</name>'
  write(88,13)'   <Point><coordinates>',slon,',',slat,'</coordinates></Point>'
  write(88,*)'   </Placemark>'
  
  do i=1,num_rec_glob
     write(88,*)
     write(88,*) ' <Placemark>'
     write(88,*) '     <Style id="cam">'
     write(88,*) '       <IconStyle>'
   write(88,*)'       <scale>5</scale>'
     write(88,*) '         <Icon>'
     if (fname=='original') then
        write(88,*) '<href>http://maps.google.com/mapfiles/kml/shapes/camera.png</href>'
     else
        write(88,*)' <href>http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png</href>'
     endif
     write(88,*) '         </Icon>'
     write(88,*) '       </IconStyle>'
  write(88,*)'                  <LabelStyle>'
  write(88,*)'                      <scale>5</scale>'
   write(88,*)'                 </LabelStyle>'
     write(88,*) '     </Style>'
     write(88,17) ' <name>',trim(receiver_name(i)),' rec ',i,'</name>'
     call define_io_appendix(app,i)
     write(88,19) ' <description> ',trim(receiver_name(i))
     write(88,20) ' colat,lon [deg]:',rcvcolat(i),rcvlon(i)
     write(88,*) ' <img src="../Data/'//trim(receiver_name(i))//'_disp.dat_'//trim(comp(1))//'.gif"></img>'
     write(88,*) ' <img src="../Data/'//trim(receiver_name(i))//'_disp.dat_'//trim(comp(3))//'.gif"></img>'
     if (src_type(1)/='monopole') &
     write(88,*) ' <img src="../Data/'//trim(receiver_name(i))//'_disp.dat_'//trim(comp(2))//'.gif"></img>'
  
     write(88,*) '  </description>'
     write(88,13) '   <Point><coordinates>',rlon(i),',',rlat(i),'</coordinates></Point>'
     write(88,*) ' </Placemark>'
  enddo
  
  write(88,*)'......'
  write(88,*)
  write(88,*)'</Document>'
  write(88,*)'</kml>'
  
  close(88)

12 format(a16,f10.2,a23,f10.2,a12)
13 format(a23,f10.2,a1,f10.2,a23)
14 format(a39)
15 format(a46)
16 format(a11)
17 format(a7,a9,a10,i4,a7)
18 format(a36,a4,a14)
19 format(a24,a15)
20 format(A18,f8.2,f8.2)

end subroutine save_google_earth_kml
!=============================================================================

end module rotations
!-----------------------------------------------------------------------------
