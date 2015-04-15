cdef extern from "cantera/thermo/speciesThermoTypes.h" namespace "Cantera":
    cdef int SPECIES_THERMO_CONSTANT_CP "CONSTANT_CP"
    cdef int SPECIES_THERMO_NASA2 "NASA2"
    cdef int SPECIES_THERMO_SHOMATE2 "SHOMATE2"


cdef class SpeciesThermo:
    """
    Base class for representing the reference-state thermodynamic properties of
    a pure species. These properties are a function of temperature. Derived
    classes implement a parameterization of this temperature dependence. This is
    a wrapper for the C++ class :ct:`SpeciesThermoInterpType`.
    """
    def __cinit__(self, T_low=None, T_high=None, P_ref=None, coeffs=None, *args,
                  init=True, **kwargs):
        if not init:
            return

        if len(coeffs) != self.n_coeffs:
            raise ValueError("Coefficient array has incorrect length")
        cdef np.ndarray[np.double_t, ndim=1] data = np.ascontiguousarray(
            coeffs, dtype=np.double)
        self._spthermo.reset(CxxNewSpeciesThermo(self.derived_type, T_low,
                                                 T_high, P_ref, &data[0]))
        self.spthermo = self._spthermo.get()

    cdef _assign(self, shared_ptr[CxxSpeciesThermo] other):
        self._spthermo = other
        self.spthermo = self._spthermo.get()

    def cp(self, T):
        """ Molar heat capacity at constant pressure [J/kmol/K] """
        cdef double cp_r, h_rt, s_r
        self.spthermo.updatePropertiesTemp(T, &cp_r, &h_rt, &s_r)
        return cp_r * gas_constant

    def h(self, T):
        """ Molar enthalpy [J/kmol] """
        cdef double cp_r, h_rt, s_r
        self.spthermo.updatePropertiesTemp(T, &cp_r, &h_rt, &s_r)
        return h_rt * gas_constant * T

    def s(self, T):
        """ Molar entropy [J/kmol/K] """
        cdef double cp_r, h_rt, s_r
        self.spthermo.updatePropertiesTemp(T, &cp_r, &h_rt, &s_r)
        return s_r * gas_constant


cdef class ConstantCp(SpeciesThermo):
    """
    Thermodynamic properties for a species that has a constant specific heat
    capacity. This is a wrapper for the C++ class :ct:`ConstCpPoly`.
    """
    derived_type = SPECIES_THERMO_CONSTANT_CP
    n_coeffs = 4


cdef class NasaPoly2(SpeciesThermo):
    """
    Thermodynamic properties for a species which is parameterized using the
    7-coefficient NASA polynomial form in two temperature ranges. This is a
    wrapper for the C++ class :ct:`NasaPoly2`.
    """
    derived_type = SPECIES_THERMO_NASA2
    n_coeffs = 15


cdef class ShomatePoly2(SpeciesThermo):
    """
    Thermodynamic properties for a species which is parameterized using the
    Shomate equation in two temperature ranges. This is a wrapper for the C++
    class :ct:`ShomatePoly2`.
    """
    derived_type = SPECIES_THERMO_SHOMATE2
    n_coeffs = 15


cdef wrapSpeciesThermo(shared_ptr[CxxSpeciesThermo] spthermo):
    """
    Wrap a C++ SpeciesThermoInterpType object with a Python object of the
    correct derived type.
    """
    cdef int thermo_type = spthermo.get().reportType()

    if thermo_type == SPECIES_THERMO_NASA2:
        st = NasaPoly2(init=False)
    elif thermo_type == SPECIES_THERMO_CONSTANT_CP:
        st = ConstantCp(init=False)
    elif thermo_type == SPECIES_THERMO_SHOMATE2:
        st = ShomatePoly2(init=False)
    else:
        st = SpeciesThermo()

    st._assign(spthermo)
    return st
