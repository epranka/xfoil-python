C***********************************************************************
C    Module:  xgeom.f
C 
C    Copyright (C) 2000 Mark Drela 
C 
C    This program is free software; you can redistribute it and/or modify
C    it under the terms of the GNU General Public License as published by
C    the Free Software Foundation; either version 2 of the License, or
C    (at your option) any later version.
C
C    This program is distributed in the hope that it will be useful,
C    but WITHOUT ANY WARRANTY; without even the implied warranty of
C    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
C    GNU General Public License for more details.
C
C    You should have received a copy of the GNU General Public License
C    along with this program; if not, write to the Free Software
C    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
C***********************************************************************

      SUBROUTINE LEFIND(SLE,X,XP,Y,YP,S,N)
      DIMENSION X(*),XP(*),Y(*),YP(*),S(*)
C------------------------------------------------------
C     Locates leading edge spline-parameter value SLE
C
C     The defining condition is
C         
C      (X-XTE,Y-YTE) . (X',Y') = 0     at  S = SLE
C
C     i.e. the surface tangent is normal to the chord
C     line connecting X(SLE),Y(SLE) and the TE point.
C------------------------------------------------------
C
C---- convergence tolerance
      DSEPS = (S(N)-S(1)) * 1.0E-5
C
C---- set trailing edge point coordinates
      XTE = 0.5*(X(1) + X(N))
      YTE = 0.5*(Y(1) + Y(N))
C
C---- get first guess for SLE
      DO 10 I=3, N-2
        DXTE = X(I) - XTE
        DYTE = Y(I) - YTE
        DX = X(I+1) - X(I)
        DY = Y(I+1) - Y(I)
        DOTP = DXTE*DX + DYTE*DY
        IF(DOTP .LT. 0.0) GO TO 11
   10 CONTINUE
C
   11 SLE = S(I)
C
C---- check for sharp LE case
      IF(S(I) .EQ. S(I-1)) THEN
ccc        WRITE(*,*) 'Sharp LE found at ',I,SLE
        RETURN
      ENDIF
C
C---- Newton iteration to get exact SLE value
      DO 20 ITER=1, 50
        XLE  = SEVAL(SLE,X,XP,S,N)
        YLE  = SEVAL(SLE,Y,YP,S,N)
        DXDS = DEVAL(SLE,X,XP,S,N)
        DYDS = DEVAL(SLE,Y,YP,S,N)
        DXDD = D2VAL(SLE,X,XP,S,N)
        DYDD = D2VAL(SLE,Y,YP,S,N)
C
        XCHORD = XLE - XTE
        YCHORD = YLE - YTE
C
C------ drive dot product between chord line and LE tangent to zero
        RES  = XCHORD*DXDS + YCHORD*DYDS
        RESS = DXDS  *DXDS + DYDS  *DYDS
     &       + XCHORD*DXDD + YCHORD*DYDD
C
C------ Newton delta for SLE 
        DSLE = -RES/RESS
C
        DSLE = MAX( DSLE , -0.02*ABS(XCHORD+YCHORD) )
        DSLE = MIN( DSLE ,  0.02*ABS(XCHORD+YCHORD) )
        SLE = SLE + DSLE
        IF(ABS(DSLE) .LT. DSEPS) RETURN
   20 CONTINUE
      WRITE(*,*) 'LEFIND:  LE point not found.  Continuing...'
      SLE = S(I)
      RETURN
      END


      SUBROUTINE SOPPS(SOPP, SI, X,XP,Y,YP,S,N, SLE)
      DIMENSION X(*),XP(*),Y(*),YP(*),S(*)
C--------------------------------------------------
C     Calculates arc length SOPP of point 
C     which is opposite of point SI, on the 
C     other side of the airfoil baseline
C--------------------------------------------------
C
C---- reference length for testing convergence
      SLEN = S(N) - S(1)
C
C---- set chordline vector
      XLE = SEVAL(SLE,X,XP,S,N)
      YLE = SEVAL(SLE,Y,YP,S,N)
      XTE = 0.5*(X(1)+X(N))
      YTE = 0.5*(Y(1)+Y(N))
      CHORD = SQRT((XTE-XLE)**2 + (YTE-YLE)**2)
      DXC = (XTE-XLE) / CHORD
      DYC = (YTE-YLE) / CHORD
C
      IF(SI.LT.SLE) THEN
       IN = 1
       INOPP = N
      ELSE
       IN = N
       INOPP = 1
      ENDIF
      SFRAC = (SI-SLE)/(S(IN)-SLE)
      SOPP = SLE + SFRAC*(S(INOPP)-SLE)
C     
      IF(ABS(SFRAC) .LE. 1.0E-5) THEN
       SOPP = SLE
       RETURN
      ENDIF
C
C---- XBAR = x coordinate in chord-line axes
      XI  = SEVAL(SI , X,XP,S,N)
      YI  = SEVAL(SI , Y,YP,S,N)
      XLE = SEVAL(SLE, X,XP,S,N)
      YLE = SEVAL(SLE, Y,YP,S,N)
      XBAR = (XI-XLE)*DXC + (YI-YLE)*DYC
C
C---- converge on exact opposite point with same XBAR value
      DO 300 ITER=1, 12
        XOPP  = SEVAL(SOPP,X,XP,S,N)
        YOPP  = SEVAL(SOPP,Y,YP,S,N)
        XOPPD = DEVAL(SOPP,X,XP,S,N)
        YOPPD = DEVAL(SOPP,Y,YP,S,N)
C
        RES  = (XOPP -XLE)*DXC + (YOPP -YLE)*DYC - XBAR
        RESD =  XOPPD     *DXC +  YOPPD     *DYC
C
        IF(ABS(RES)/SLEN .LT. 1.0E-5) GO TO 305
        IF(RESD .EQ. 0.0) GO TO 303
C
        DSOPP = -RES/RESD
        SOPP = SOPP + DSOPP
C
        IF(ABS(DSOPP)/SLEN .LT. 1.0E-5) GO TO 305
 300  CONTINUE
 303  WRITE(*,*)
     &      'SOPPS: Opposite-point location failed. Continuing...'
      SOPP = SLE + SFRAC*(S(INOPP)-SLE)
C
 305  CONTINUE
      RETURN
      END ! SOPPS


 
      SUBROUTINE NORM(X,XP,Y,YP,S,N)
      DIMENSION X(*),XP(*),Y(*),YP(*),S(*)
C-----------------------------------------------
C     Scales coordinates to get unit chord
C-----------------------------------------------
C
      CALL SCALC(X,Y,S,N)
      CALL SEGSPL(X,XP,S,N)
      CALL SEGSPL(Y,YP,S,N)
C
      CALL LEFIND(SLE,X,XP,Y,YP,S,N)
C
      XMAX = 0.5*(X(1) + X(N))
      XMIN = SEVAL(SLE,X,XP,S,N)
      YMIN = SEVAL(SLE,Y,YP,S,N)
C
      FUDGE = 1.0/(XMAX-XMIN)
      DO 40 I=1, N
        X(I) = (X(I)-XMIN)*FUDGE
        Y(I) = (Y(I)-YMIN)*FUDGE
        S(I) = S(I)*FUDGE
   40 CONTINUE
C
      RETURN
      END


      SUBROUTINE GEOPAR(X,XP,Y,YP,S,N, T,
     &             SLE,CHORD,AREA,RADLE,ANGTE,
     &             EI11A,EI22A,APX1A,APX2A,
     &             EI11T,EI22T,APX1T,APX2T,
     &             THICK,CAMBR)
      DIMENSION X(*), XP(*), Y(*), YP(*), S(*), T(*)
C
      PARAMETER (IBX=600)
      DIMENSION
     &     XCAM(2*IBX), YCAM(2*IBX), YCAMP(2*IBX),
     &     XTHK(2*IBX), YTHK(2*IBX), YTHKP(2*IBX)
C------------------------------------------------------
C     Sets geometric parameters for airfoil shape
C------------------------------------------------------
      CALL LEFIND(SLE,X,XP,Y,YP,S,N)
C
      XLE = SEVAL(SLE,X,XP,S,N)
      YLE = SEVAL(SLE,Y,YP,S,N)
      XTE = 0.5*(X(1)+X(N))
      YTE = 0.5*(Y(1)+Y(N))
C
      CHSQ = (XTE-XLE)**2 + (YTE-YLE)**2
      CHORD = SQRT(CHSQ)
C
      CURVLE = CURV(SLE,X,XP,Y,YP,S,N)
C
      RADLE = 0.0
      IF(ABS(CURVLE) .GT. 0.001*(S(N)-S(1))) RADLE = 1.0 / CURVLE
C
      ANG1 = ATAN2( -YP(1) , -XP(1) )
      ANG2 = ATANC(  YP(N) ,  XP(N) , ANG1 )
      ANGTE = ANG2 - ANG1
C

      DO I=1, N
        T(I) = 1.0
      ENDDO
C
      CALL AECALC(N,X,Y,T, 1, 
     &            AREA,XCENA,YCENA,EI11A,EI22A,APX1A,APX2A)
C
      CALL AECALC(N,X,Y,T, 2, 
     &            SLEN,XCENT,YCENT,EI11T,EI22T,APX1T,APX2T)
C
C--- Old, approximate thickness,camber routine (on discrete points only)
      CALL TCCALC(X,XP,Y,YP,S,N, THICK,XTHICK, CAMBR,XCAMBR )
C
C--- More accurate thickness and camber estimates
cc      CALL GETCAM(XCAM,YCAM,NCAM,XTHK,YTHK,NTHK,
cc     &            X,XP,Y,YP,S,N )
cc      CALL GETMAX(XCAM,YCAM,YCAMP,NCAM,XCAMBR,CAMBR)
cc      CALL GETMAX(XTHK,YTHK,YTHKP,NTHK,XTHICK,THICK)
cc      THICK = 2.0*THICK
C
      WRITE(*,1000) THICK,XTHICK,CAMBR,XCAMBR
 1000 FORMAT( ' Max thickness = ',F12.6,'  at x = ',F7.3,
     &       /' Max camber    = ',F12.6,'  at x = ',F7.3)


C
      RETURN
      END ! GEOPAR


      SUBROUTINE AECALC(N,X,Y,T, ITYPE, 
     &                  AREA,XCEN,YCEN,EI11,EI22,APX1,APX2)
      DIMENSION X(*),Y(*),T(*)
C---------------------------------------------------------------
C     Calculates geometric properties of shape X,Y
C
C     Input:
C       N      number of points
C       X(.)   shape coordinate point arrays
C       Y(.)
C       T(.)   skin-thickness array, used only if ITYPE = 2
C       ITYPE  = 1 ...   integration is over whole area  dx dy
C              = 2 ...   integration is over skin  area   t ds
C
C     Output:
C       XCEN,YCEN  centroid location
C       EI11,EI22  principal moments of inertia
C       APX1,APX2  principal-axis angles
C---------------------------------------------------------------
      DATA PI / 3.141592653589793238 /
C
      SINT  = 0.0
      AINT  = 0.0
      XINT  = 0.0
      YINT  = 0.0
      XXINT = 0.0
      XYINT = 0.0
      YYINT = 0.0
C
      DO 10 IO = 1, N
        IF(IO.EQ.N) THEN
          IP = 1
        ELSE
          IP = IO + 1
        ENDIF
C
        DX =  X(IO) - X(IP)
        DY =  Y(IO) - Y(IP)
        XA = (X(IO) + X(IP))*0.50
        YA = (Y(IO) + Y(IP))*0.50
        TA = (T(IO) + T(IP))*0.50
C
        DS = SQRT(DX*DX + DY*DY)
        SINT = SINT + DS

        IF(ITYPE.EQ.1) THEN
C-------- integrate over airfoil cross-section
          DA = YA*DX
          AINT  = AINT  +       DA
          XINT  = XINT  + XA   *DA
          YINT  = YINT  + YA   *DA/2.0
          XXINT = XXINT + XA*XA*DA
          XYINT = XYINT + XA*YA*DA/2.0
          YYINT = YYINT + YA*YA*DA/3.0
        ELSE
C-------- integrate over skin thickness
          DA = TA*DS
          AINT  = AINT  +       DA
          XINT  = XINT  + XA   *DA
          YINT  = YINT  + YA   *DA
          XXINT = XXINT + XA*XA*DA
          XYINT = XYINT + XA*YA*DA
          YYINT = YYINT + YA*YA*DA
        ENDIF
C
 10   CONTINUE
C
      AREA = AINT
C
      IF(AINT .EQ. 0.0) THEN
        XCEN  = 0.0
        YCEN  = 0.0
        EI11  = 0.0
        EI22  = 0.0
        APX1 = 0.0
        APX2 = ATAN2(1.0,0.0)
        RETURN
      ENDIF
C
C
C---- calculate centroid location
      XCEN = XINT/AINT
      YCEN = YINT/AINT
C
C---- calculate inertias
      EIXX = YYINT - YCEN*YCEN*AINT
      EIXY = XYINT - XCEN*YCEN*AINT
      EIYY = XXINT - XCEN*XCEN*AINT
C
C---- set principal-axis inertias, EI11 is closest to "up-down" bending inertia
      EISQ  = 0.25*(EIXX - EIYY)**2  + EIXY**2
      SGN = SIGN( 1.0 , EIYY-EIXX )
      EI11 = 0.5*(EIXX + EIYY) - SGN*SQRT(EISQ)
      EI22 = 0.5*(EIXX + EIYY) + SGN*SQRT(EISQ)
C
      IF(EI11.EQ.0.0 .OR. EI22.EQ.0.0) THEN
C----- vanishing section stiffness
       APX1 = 0.0
       APX2 = ATAN2(1.0,0.0)
C
      ELSEIF(EISQ/(EI11*EI22) .LT. (0.001*SINT)**4) THEN
C----- rotationally-invariant section (circle, square, etc.)
       APX1 = 0.0
       APX2 = ATAN2(1.0,0.0)
C
      ELSE
C----- normal airfoil section
       C1 = EIXY
       S1 = EIXX-EI11
C
       C2 = EIXY
       S2 = EIXX-EI22
C
       IF(ABS(S1).GT.ABS(S2)) THEN
         APX1 = ATAN2(S1,C1)
         APX2 = APX1 + 0.5*PI
       ELSE
         APX2 = ATAN2(S2,C2)
         APX1 = APX2 - 0.5*PI
       ENDIF

       IF(APX1.LT.-0.5*PI) APX1 = APX1 + PI
       IF(APX1.GT.+0.5*PI) APX1 = APX1 - PI
       IF(APX2.LT.-0.5*PI) APX2 = APX2 + PI
       IF(APX2.GT.+0.5*PI) APX2 = APX2 - PI
C
      ENDIF
C
      RETURN
      END ! AECALC



      SUBROUTINE TCCALC(X,XP,Y,YP,S,N, 
     &                  THICK,XTHICK, CAMBR,XCAMBR )
      DIMENSION X(*),XP(*),Y(*),YP(*),S(*)
C---------------------------------------------------------------
C     Calculates max thickness and camber at airfoil points
C
C     Note: this routine does not find the maximum camber or 
C           thickness exactly as it only looks at discrete points
C
C     Input:
C       N      number of points
C       X(.)   shape coordinate point arrays
C       Y(.)
C
C     Output:
C       THICK  max thickness
C       CAMBR  max camber
C---------------------------------------------------------------
      CALL LEFIND(SLE,X,XP,Y,YP,S,N)
      XLE = SEVAL(SLE,X,XP,S,N)
      YLE = SEVAL(SLE,Y,YP,S,N)
      XTE = 0.5*(X(1)+X(N))
      YTE = 0.5*(Y(1)+Y(N))
      CHORD = SQRT((XTE-XLE)**2 + (YTE-YLE)**2)
C
C---- set unit chord-line vector
      DXC = (XTE-XLE) / CHORD
      DYC = (YTE-YLE) / CHORD
C
      THICK = 0.
      XTHICK = 0.
      CAMBR = 0.
      XCAMBR = 0.
C
C---- go over each point, finding the y-thickness and camber
      DO 30 I=1, N
        XBAR = (X(I)-XLE)*DXC + (Y(I)-YLE)*DYC
        YBAR = (Y(I)-YLE)*DXC - (X(I)-XLE)*DYC
C
C------ set point on the opposite side with the same chord x value
        CALL SOPPS(SOPP, S(I), X,XP,Y,YP,S,N, SLE)
        XOPP = SEVAL(SOPP,X,XP,S,N)
        YOPP = SEVAL(SOPP,Y,YP,S,N)
C
        YBAROP = (YOPP-YLE)*DXC - (XOPP-XLE)*DYC
C
        YC = 0.5*(YBAR+YBAROP)
        YT =  ABS(YBAR-YBAROP)
C
        IF(ABS(YC) .GT. ABS(CAMBR)) THEN
         CAMBR = YC
         XCAMBR = XOPP
        ENDIF
        IF(ABS(YT) .GT. ABS(THICK)) THEN
         THICK = YT
         XTHICK = XOPP
        ENDIF
   30 CONTINUE
C
      RETURN
      END ! TCCALC




      SUBROUTINE CANG(X,Y,N,IPRINT, IMAX,AMAX)
      DIMENSION X(*), Y(*)
C-------------------------------------------------------------------
C     IPRINT=2:   Displays all panel node corner angles
C     IPRINT=1:   Displays max panel node corner angle
C     IPRINT=0:   No display... just returns values
C-------------------------------------------------------------------
C
      AMAX = 0.0
      IMAX = 1
C
C---- go over each point, calculating corner angle
      IF(IPRINT.EQ.2) WRITE(*,1050)
      DO 30 I=2, N-1
        DX1 = X(I) - X(I-1)
        DY1 = Y(I) - Y(I-1)
        DX2 = X(I) - X(I+1)
        DY2 = Y(I) - Y(I+1)
C
C------ allow for doubled points
        IF(DX1.EQ.0.0 .AND. DY1.EQ.0.0) THEN
         DX1 = X(I) - X(I-2)
         DY1 = Y(I) - Y(I-2)
        ENDIF
        IF(DX2.EQ.0.0 .AND. DY2.EQ.0.0) THEN
         DX2 = X(I) - X(I+2)
         DY2 = Y(I) - Y(I+2)
        ENDIF
C
        CROSSP = (DX2*DY1 - DY2*DX1)
     &         / SQRT((DX1**2 + DY1**2) * (DX2**2 + DY2**2))
        ANGL = ASIN(CROSSP)*(180.0/3.1415926)
        IF(IPRINT.EQ.2) WRITE(*,1100) I, X(I), Y(I), ANGL
        IF(ABS(ANGL) .GT. ABS(AMAX)) THEN
         AMAX = ANGL
         IMAX = I
        ENDIF
   30 CONTINUE
C
      IF(IPRINT.GE.1) WRITE(*,1200) AMAX, IMAX, X(IMAX), Y(IMAX)
C
      RETURN
C
 1050 FORMAT(/'  i       x        y      angle')
CCC             120   0.2134  -0.0234   25.322
 1100 FORMAT(1X,I3, 2F9.4, F9.3)
 1200 FORMAT(/' Maximum panel corner angle =', F7.3,
     &        '   at  i,x,y  = ', I3, 2F9.4 )
      END ! CANG



      SUBROUTINE INTER(X0,XP0,Y0,YP0,S0,N0,SLE0,
     &                 X1,XP1,Y1,YP1,S1,N1,SLE1,
     &                 X,Y,N,FRAC)
C     .....................................................................
C
C     Interpolates two source airfoil shapes into an "intermediate" shape.
C
C     Procedure:
C        The interpolated x coordinate at a given normalized spline 
C        parameter value is a weighted average of the two source 
C        x coordinates at the same normalized spline parameter value.
C        Ditto for the y coordinates. The normalized spline parameter 
C        runs from 0 at the leading edge to 1 at the trailing edge on 
C        each surface.
C     .....................................................................
C
      REAL X0(N0),Y0(N0),XP0(N0),YP0(N0),S0(N0)
      REAL X1(N1),Y1(N1),XP1(N1),YP1(N1),S1(N1)
      REAL X(*),Y(*)
C
C---- number of points in interpolated airfoil is the same as in airfoil 0
      N = N0
C
C---- interpolation weighting fractions
      F0 = 1.0 - FRAC
      F1 = FRAC
C
C---- top side spline parameter increments
      TOPS0 = S0(1) - SLE0
      TOPS1 = S1(1) - SLE1
C
C---- bottom side spline parameter increments
      BOTS0 = S0(N0) - SLE0
      BOTS1 = S1(N1) - SLE1
C
      DO 50 I=1, N
C
C------ normalized spline parameter is taken from airfoil 0 value
        IF(S0(I).LT.SLE0) SN = (S0(I) - SLE0) / TOPS0    ! top side
        IF(S0(I).GE.SLE0) SN = (S0(I) - SLE0) / BOTS0    ! bottom side
C
C------ set actual spline parameters
        ST0 = S0(I)
        IF(ST0.LT.SLE0) ST1 = SLE1 + TOPS1 * SN
        IF(ST0.GE.SLE0) ST1 = SLE1 + BOTS1 * SN
C
C------ set input coordinates at common spline parameter location
        XT0 = SEVAL(ST0,X0,XP0,S0,N0)
        YT0 = SEVAL(ST0,Y0,YP0,S0,N0)
        XT1 = SEVAL(ST1,X1,XP1,S1,N1)
        YT1 = SEVAL(ST1,Y1,YP1,S1,N1)
C
C------ set interpolated x,y coordinates
        X(I) = F0*XT0 + F1*XT1
        Y(I) = F0*YT0 + F1*YT1
C
   50 CONTINUE
C
      RETURN
      END ! INTER



      SUBROUTINE INTERX(X0,XP0,Y0,YP0,S0,N0,SLE0,
     &                  X1,XP1,Y1,YP1,S1,N1,SLE1,
     &                  X,Y,N,FRAC)
C     .....................................................................
C
C     Interpolates two source airfoil shapes into an "intermediate" shape.
C
C     Procedure:
C        The interpolated x coordinate at a given normalized spline 
C        parameter value is a weighted average of the two source 
C        x coordinates at the same normalized spline parameter value.
C        Ditto for the y coordinates. The normalized spline parameter 
C        runs from 0 at the leading edge to 1 at the trailing edge on 
C        each surface.
C     .....................................................................
C
      REAL X0(N0),Y0(N0),XP0(N0),YP0(N0),S0(N0)
      REAL X1(N1),Y1(N1),XP1(N1),YP1(N1),S1(N1)
      REAL X(N),Y(N)
C
C---- number of points in interpolated airfoil is the same as in airfoil 0
      N = N0
C
C---- interpolation weighting fractions
      F0 = 1.0 - FRAC
      F1 = FRAC
C
      XLE0 = SEVAL(SLE0,X0,XP0,S0,N0)
      XLE1 = SEVAL(SLE1,X1,XP1,S1,N1)
C
      DO 50 I=1, N
C
C------ normalized x parameter is taken from airfoil 0 value
        IF(S0(I).LT.SLE0) XN = (X0(I) - XLE0) / (X0( 1) - XLE0)
        IF(S0(I).GE.SLE0) XN = (X0(I) - XLE0) / (X0(N0) - XLE0)
C
C------ set target x and initial spline parameters
        XT0 = X0(I)
        ST0 = S0(I)
        IF(ST0.LT.SLE0) THEN
         XT1 = XLE1 + (X1( 1) - XLE1) * XN
         ST1 = SLE1 + (S1( 1) - SLE1) * XN
        ELSE
         XT1 = XLE1 + (X1(N1) - XLE1) * XN
         ST1 = SLE1 + (S1(N1) - SLE1) * XN
        ENDIF
C
        CALL SINVRT(ST0,XT0,X0,XP0,S0,N0)
        CALL SINVRT(ST1,XT1,X1,XP1,S1,N1)
C
C------ set input coordinates at common spline parameter location
        XT0 = SEVAL(ST0,X0,XP0,S0,N0)
        YT0 = SEVAL(ST0,Y0,YP0,S0,N0)
        XT1 = SEVAL(ST1,X1,XP1,S1,N1)
        YT1 = SEVAL(ST1,Y1,YP1,S1,N1)
C
C------ set interpolated x,y coordinates
        X(I) = F0*XT0 + F1*XT1
        Y(I) = F0*YT0 + F1*YT1
C
   50 CONTINUE
C
      RETURN
      END ! INTERX





      SUBROUTINE BENDUMP(N,X,Y)
      REAL X(*), Y(*)
C
      PEX = 16.0
      CALL IJSECT(N,X,Y, PEX,
     &  AREA, SLEN, 
     &  XMIN, XMAX, XEXINT,
     &  YMIN, YMAX, YEXINT,
     &  XC , YC , 
     &  XCT, YCT, 
     &  AIXX , AIYY , 
     &  AIXXT, AIYYT,
     &  AJ   , AJT    )
c      CALL IJSECT(N,X,Y, PEX,
c     &    AREA, SLEN, 
c     &    XC, XMIN, XMAX, XEXINT,
c     &    YC, YMIN, YMAX, YEXINT,
c     &    AIXX, AIXXT,
c     &    AIYY, AIYYT,
c     &    AJ  , AJT   )
C
      WRITE(*,*) 
      WRITE(*,1200) 'Area =', AREA
      WRITE(*,1200) 'Slen =', SLEN
      WRITE(*,*)
      WRITE(*,1200) 'X-bending parameters(solid):'
      WRITE(*,1200) '        Xc =', XC
      WRITE(*,1200) '  max X-Xc =', XMAX-XC
      WRITE(*,1200) '  min X-Xc =', XMIN-XC
      WRITE(*,1200) '       Iyy =', AIYY
      XBAR = MAX( ABS(XMAX-XC) , ABS(XMIN-XC) )
      WRITE(*,1200) ' Iyy/(X-Xc)=', AIYY /XBAR
      WRITE(*,*)
      WRITE(*,1200) 'Y-bending parameters(solid):'
      WRITE(*,1200) '        Yc =', YC
      WRITE(*,1200) '  max Y-Yc =', YMAX-YC
      WRITE(*,1200) '  min Y-Yc =', YMIN-YC
      WRITE(*,1200) '       Ixx =', AIXX
      YBAR = MAX( ABS(YMAX-YC) , ABS(YMIN-YC) )
      WRITE(*,1200) ' Ixx/(Y-Yc)=', AIXX /YBAR
      WRITE(*,*)
      WRITE(*,1200) '       J   =', AJ
C
      WRITE(*,*)
      WRITE(*,*)
      WRITE(*,1200) 'X-bending parameters(skin):'
      WRITE(*,1200) '         Xc =', XCT
      WRITE(*,1200) '   max X-Xc =', XMAX-XCT
      WRITE(*,1200) '   min X-Xc =', XMIN-XCT
      WRITE(*,1200) '      Iyy/t =', AIYYT
      XBART = MAX( ABS(XMAX-XCT) , ABS(XMIN-XCT) )
      WRITE(*,1200) ' Iyy/t(X-Xc)=', AIYYT /XBART
      WRITE(*,*)
      WRITE(*,1200) 'Y-bending parameters(skin):'
      WRITE(*,1200) '         Yc =', YCT
      WRITE(*,1200) '   max Y-Yc =', YMAX-YCT
      WRITE(*,1200) '   min Y-Yc =', YMIN-YCT
      WRITE(*,1200) '      Ixx/t =', AIXXT
      YBART = MAX( ABS(YMAX-YCT) , ABS(YMIN-YCT) )
      WRITE(*,1200) ' Ixx/t(Y-Yc)=', AIXXT /YBART
      WRITE(*,*)
      WRITE(*,1200) '      J/t   =', AJT
C
c      WRITE(*,*)
c      WRITE(*,1200) '  power-avg X-Xc =', XEXINT
c      WRITE(*,1200) '  power-avg Y-Yc =', YEXINT
C
      RETURN
C
 1200 FORMAT(1X,A,G14.6)
      END ! BENDUMP



      SUBROUTINE BENDUMP2(N,X,Y,T)
      REAL X(*), Y(*), T(*)
C
      DTR = ATAN(1.0) / 45.0
C
      PEX = 16.0
      CALL IJSECT(N,X,Y, PEX,
     &  AREA, SLEN, 
     &  XMIN, XMAX, XEXINT,
     &  YMIN, YMAX, YEXINT,
     &  XC , YC , 
     &  XCT, YCT, 
     &  AIXX , AIYY , 
     &  AIXXT, AIYYT,
     &  AJ   , AJT    )
c      CALL IJSECT(N,X,Y, PEX,
c     &    AREA, SLEN, 
c     &    XC, XMIN, XMAX, XEXINT,
c     &    YC, YMIN, YMAX, YEXINT,
c     &    AIXX, AIXXT,
c     &    AIYY, AIYYT,
c     &    AJ  , AJT   )
C
C
      CALL AECALC(N,X,Y,T, 1, 
     &            AREA,XCENA,YCENA,EI11A,EI22A,APX1A,APX2A)
C
      CALL AECALC(N,X,Y,T, 2, 
     &            SLEN,XCENT,YCENT,EI11T,EI22T,APX1T,APX2T)
C

      WRITE(*,*) 
      WRITE(*,1200) 'Area =', AREA
      WRITE(*,1200) 'Slen =', SLEN
      WRITE(*,*)
      WRITE(*,1200) 'X-bending parameters:'
      WRITE(*,1200) 'solid centroid Xc=', XCENA
      WRITE(*,1200) 'skin  centroid Xc=', XCENT
      WRITE(*,1200) ' solid max X-Xc  =', XMAX-XCENA
      WRITE(*,1200) ' solid min X-Xc  =', XMIN-XCENA
      WRITE(*,1200) ' skin  max X-Xc  =', XMAX-XCENT
      WRITE(*,1200) ' skin  min X-Xc  =', XMIN-XCENT
      WRITE(*,1200) '     solid Iyy   =', EI22A
      WRITE(*,1200) '     skin  Iyy/t =', EI22T
      XBARA = MAX( ABS(XMAX-XCENA) , ABS(XMIN-XCENA) )
      XBART = MAX( ABS(XMAX-XCENT) , ABS(XMIN-XCENT) )
      WRITE(*,1200) ' solid Iyy/(X-Xc)=', EI22A/XBARA
      WRITE(*,1200) ' skin Iyy/t(X-Xc)=', EI22T/XBART
C
      WRITE(*,*)
      WRITE(*,1200) 'Y-bending parameters:'
      WRITE(*,1200) 'solid centroid Yc=', YCENA
      WRITE(*,1200) 'skin  centroid Yc=', YCENT
      WRITE(*,1200) ' solid max Y-Yc  =', YMAX-YCENA
      WRITE(*,1200) ' solid min Y-Yc  =', YMIN-YCENA
      WRITE(*,1200) ' skin  max Y-Yc  =', YMAX-YCENT
      WRITE(*,1200) ' skin  min Y-Yc  =', YMIN-YCENT
      WRITE(*,1200) '     solid Ixx   =', EI11A
      WRITE(*,1200) '     skin  Ixx/t =', EI11T
      YBARA = MAX( ABS(YMAX-YCENA) , ABS(YMIN-YCENA) )
      YBART = MAX( ABS(YMAX-YCENT) , ABS(YMIN-YCENT) )
      WRITE(*,1200) ' solid Ixx/(Y-Yc)=', EI11A/YBARA
      WRITE(*,1200) ' skin Ixx/t(Y-Yc)=', EI11T/YBART
C
      WRITE(*,*)
      WRITE(*,1200) ' solid principal axis angle (deg ccw) =', APX1A/DTR
      WRITE(*,1200) ' skin  principal axis angle (deg ccw) =', APX1T/DTR

c      WRITE(*,*)
c      WRITE(*,1200) '  power-avg X-Xc =', XEXINT
c      WRITE(*,1200) '  power-avg Y-Yc =', YEXINT
C
      WRITE(*,*)
      WRITE(*,1200) '    solid J     =', AJ
      WRITE(*,1200) '    skin  J/t   =', AJT
      RETURN
C
 1200 FORMAT(1X,A,G14.6)
      END ! BENDUMP2



      SUBROUTINE IJSECT(N,X,Y, PEX,
     &  AREA, SLEN, 
     &  XMIN, XMAX, XEXINT,
     &  YMIN, YMAX, YEXINT,
     &  XC , YC , 
     &  XCT, YCT, 
     &  AIXX , AIYY , 
     &  AIXXT, AIYYT,
     &  AJ   , AJT    )
      DIMENSION X(*), Y(*)
C
      XMIN = X(1)
      XMAX = X(1)
      YMIN = Y(1)
      YMAX = Y(1)
C
      DX = X(1) - X(N)
      DY = Y(1) - Y(N)
      DS = SQRT(DX*DX + DY*DY)
      XAVG = 0.5*(X(1) + X(N))
      YAVG = 0.5*(Y(1) + Y(N))
C
      X_DY   = DY * XAVG
      XX_DY  = DY * XAVG**2
      XXX_DY = DY * XAVG**3
      X_DS   = DS * XAVG
      XX_DS  = DS * XAVG**2
C
      Y_DX   = DX * YAVG
      YY_DX  = DX * YAVG**2
      YYY_DX = DX * YAVG**3
      Y_DS   = DS * YAVG
      YY_DS  = DS * YAVG**2
C
      C_DS   = DS
C
      DO 10 I = 2, N
        DX = X(I) - X(I-1)
        DY = Y(I) - Y(I-1)
        DS = SQRT(DX*DX + DY*DY)
        XAVG = 0.5*(X(I) + X(I-1))
        YAVG = 0.5*(Y(I) + Y(I-1))
C
        X_DY   = X_DY   + DY * XAVG
        XX_DY  = XX_DY  + DY * XAVG**2
        XXX_DY = XXX_DY + DY * XAVG**3
        X_DS   = X_DS   + DS * XAVG
        XX_DS  = XX_DS  + DS * XAVG**2
C
        Y_DX   = Y_DX   + DX * YAVG
        YY_DX  = YY_DX  + DX * YAVG**2
        YYY_DX = YYY_DX + DX * YAVG**3
        Y_DS   = Y_DS   + DS * YAVG
        YY_DS  = YY_DS  + DS * YAVG**2
C
        C_DS   = C_DS   + DS
C
        XMIN = MIN(XMIN,X(I))
        XMAX = MAX(XMAX,X(I))
        YMIN = MIN(YMIN,Y(I))
        YMAX = MAX(YMAX,Y(I))
 10   CONTINUE
C
      AREA = -Y_DX
      SLEN =  C_DS
C
      IF(AREA.EQ.0.0) RETURN
C
      XC = XX_DY / (2.0*X_DY)
      XCT = X_DS / C_DS
      AIYY  =  XXX_DY/3.0 - XX_DY*XC      + X_DY*XC**2
      AIYYT =   XX_DS     -  X_DS*XCT*2.0 + C_DS*XCT**2
C
      YC = YY_DX / (2.0*Y_DX)
      YCT = Y_DS / C_DS
      AIXX  = -YYY_DX/3.0 + YY_DX*YC      - Y_DX*YC**2
      AIXXT =   YY_DS     -  Y_DS*YCT*2.0 + C_DS*YCT**2
C
C
      SINT = 0.
      XINT = 0.
      YINT = 0.
C
      DO 20 I=2, N
        DX = X(I) - X(I-1)
        DY = Y(I) - Y(I-1)
        DS = SQRT(DX*DX + DY*DY)
        XAVG = 0.5*(X(I) + X(I-1)) - XC
        YAVG = 0.5*(Y(I) + Y(I-1)) - YC
C
        SINT = SINT + DS
cc        XINT = XINT + DS * ABS(XAVG)**PEX
cc        YINT = YINT + DS * ABS(YAVG)**PEX
 20   CONTINUE
C
      DO I=1, N-1
        IF(X(I+1) .GE. X(I)) GO TO 30
      ENDDO
      IMID = N/2
 30   IMID = I
C
      AJ = 0.0
      DO I = 2, IMID
        XAVG = 0.5*(X(I) + X(I-1))
        YAVG = 0.5*(Y(I) + Y(I-1))
        DX = X(I-1) - X(I)
C
        IF(XAVG.GT.X(N)) THEN
         YOPP = Y(N)
         GO TO 41
        ENDIF
        IF(XAVG.LE.X(IMID)) THEN
         YOPP = Y(IMID)
         GO TO 41
        ENDIF
C
        DO J = N, IMID, -1
          IF(XAVG.GT.X(J-1) .AND. XAVG.LE.X(J)) THEN
            FRAC = (XAVG - X(J-1))
     &           / (X(J) - X(J-1))
            YOPP = Y(J-1) + (Y(J)-Y(J-1))*FRAC
            GO TO 41
          ENDIF
        ENDDO
 41     CONTINUE
C
        AJ = AJ + ABS(YAVG-YOPP)**3 * DX / 3.0
      ENDDO
C
      AJT = 4.0*AREA**2/SLEN
C
cc      XEXINT = (XINT/SINT)**(1.0/PEX)
cc      YEXINT = (YINT/SINT)**(1.0/PEX)
C
      RETURN
      END ! IJSECT


      SUBROUTINE HALF(X,Y,S,N)
C-------------------------------------------------
C     Halves the number of points in airfoil
C-------------------------------------------------
      REAL X(*), Y(*), S(*)
C
      K = 1
      INEXT = 3
      DO 20 I=2, N-1
C------ if corner is found, preserve it.
        IF(S(I) .EQ. S(I+1)) THEN
          K = K+1
          X(K) = X(I)
          Y(K) = Y(I)
          K = K+1
          X(K) = X(I+1)
          Y(K) = Y(I+1)
          INEXT = I+3
        ENDIF
C
        IF(I.EQ.INEXT) THEN
          K = K+1
          X(K) = X(I)
          Y(K) = Y(I)
          INEXT = I+2
        ENDIF
C
   20 CONTINUE
      K = K+1
      X(K) = X(N)
      Y(K) = Y(N)
C
C---- set new number of points
      N = K
C
      RETURN
      END ! HALF


