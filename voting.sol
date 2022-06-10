// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    /**
     * @title Voter
     * @dev définit l'état du vote
     */
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint8 votedProposalId;
        uint8 authorise;
        bool isDeleted;
    }

    /*
     * @title gestion des utlisateurs authorisés par l'administrateur à procéder à un vote
     * @dev représente un mapping des addresses capables avec une structure de donnée Voter
     * @custom: génére un evement pour indiquer la crééation de l'addresse dans le mappage
     */
    mapping(address => Voter) public whiteListedPeople;

    /*
     * @title Events : déclaration de l'ensemble des évenements à capturer
     * @dev représente un mapping des addresses capables avec une structure de donnée Voter
     * @custom: génére un evement pour indiquer la crééation de l'addresse dans le mappage
     */

    event Authorized(address _address);
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    //declaration en Uint8 pour optimisation
    event ProposalRegistered(uint8 proposalId);
    event Voted(address voter, uint8 proposalId);

    /**
     * @title Proposal
     * @dev définit la proposition de vote des utilisateurs
     */

    struct Proposal {
        string description;
        //uint8 pour optimisation gaz
        uint8 voteCount;
    }

    Proposal[] votePropositions;

    /**
    * @title WorkflowStatus
    * @authorize gestion par l'administrateur du processus de vote dans le temps
    * @param enum
                RegisteringVoters => enregistrement des voteurs
                ProposalsRegistrationStarted => Commencement de la session d'enregistrement des propositions
                ProposalsRegistrationEnded => Fin de la session d'enregistrement des propositions
                VotingSessionStarted => Commencement du vote
                VotingSessionEnded => Fin de vote
                VotesTallied => comptage des votes
    * @dev authorise une addresse à voter 
    * @dev emet un evenement pour capter l'autorisation
    */

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    //déclaration de l'état initial pour les énumérations
    //je le mets en public pour avoir un getteur et que tu controle les id
    //des différentes étapes
    WorkflowStatus public defaultstate;
    WorkflowStatus previous;
    /*
     * @titre : atStage
     * @dev : Modifier pour prévenir l'appel de function hors du processus
     */

    modifier atStage(WorkflowStatus _steps) {
        require(
            defaultstate == _steps,
            "La function ne peut pas etre appele maintenant."
        );
        _;
    }

    /*
     * @titre : CheckAutorisation
     * @dev : confirme que le participant est autorisé à participer     */

    modifier CheckAutorisation() {
        require(
            whiteListedPeople[msg.sender].authorise == 1,
            "Vous n'etes pas autorise a vous enregistre, veuillez vous referer a l'administrateur"
        );
        _;
    }

    /*
     * @titre : CheckRegistration
     * @dev : confirme la resgistration des participants au vote
     */

    modifier CheckRegistration() {
        require(
            whiteListedPeople[msg.sender].isRegistered == true,
            "Vous ne vous n'etes pas enregistre..."
        );
        _;
    }

    /*
     * @title winningProposalId
     * @dev représente l’id du gagnant ou une fonction getWinner qui retourne le gagnant.
     */
    uint256 winningProposalId;

    /*
    L'administrateur de vote met fin à la session d'enregistrement des propositions.
    L'administrateur du vote commence la session de vote.
    Les électeurs inscrits votent pour leur proposition préférée.
    L'administrateur du vote met fin à la session de vote.
    L'administrateur du vote comptabilise les votes.
    Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    */
    //

    //L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.

    /*
     * @authorize gestion de la whitelist par l'administrateur
     * @param address _address
     * @return: bool
     * call: AutoRegisteristration si l'addresse est autorisé on enregistre
     * @dev authorise une addresse à voter
     * @dev emet un evenement pour capter l'autorisation
     *
     */

    function authorize(address _address)
        external
        onlyOwner
        atStage(WorkflowStatus.RegisteringVoters)
        returns (bool)
    {
        //check que l'addresse n'est pas une addresse nul=> je n'ai pas de regex
        require(_address != address(0));
        //check si la personne à dàja voter
        require(
            whiteListedPeople[_address].authorise != 1,
            "Voteur deja enregistre"
        );
        assert(whiteListedPeople[_address].isDeleted == false);

        if (whiteListedPeople[_address].authorise != 1) {
            whiteListedPeople[_address].authorise = 1;
            emit Authorized(_address);
            return true;
        }
        return false;
    }

    /*
     * @AutoRegisteristration: Permet au votant de s'enregister si il a été autorisé
     * @param address _address
     * call: internal
     * @dev enregistre le votant, declare son vote a false
     * @dev emet un evenement pour capter l'enregistrement du votant finalisé
     */

    function AutoRegisteristration()
        external
        atStage(WorkflowStatus.RegisteringVoters)
        CheckAutorisation
    {
        whiteListedPeople[msg.sender].isRegistered = true;
        whiteListedPeople[msg.sender].hasVoted = false;
        emit VoterRegistered(msg.sender);
    }

    /*
     * @titre ManageVotingFlow
     * @param uint permettant la mise à jour de la valeur de defaultstate
     * @dev assertion que l'index choisi fait partie du tableau
     * @dev attribution de la nouvelle valeur defaultstate
     */
    function ManageVotingFlow(uint8 _votingFlow) external onlyOwner {
        //verifie si le uint fait bien partie du tableau
        //je considère que VotesTallied sera toujours la dernière étapes
        //ce qui permettrait de rajouter des étapes avant sans modifié le code
        require(
            _votingFlow <= uint8(WorkflowStatus.VotesTallied),
            "Index hors du tableau"
        );

        //enregistre le statut précédant avant modification
        previous = getPrevious();

        defaultstate = WorkflowStatus(_votingFlow);

        emit WorkflowStatusChange(previous, defaultstate);
    }

    /*titre:getPrevious
     *@Dev : permet d'enregistrer la dernière valeur de WorkFlowStatus
     */
    function getPrevious() internal view returns (WorkflowStatus) {
        return defaultstate;
    }

    /*titre:incrementStatus : utilisation de incrementStatus pour facilité la gestion du flow par admin
     *@Dev : incremente de +1 le statue, passe à l'étape suivante
     *@Dev: emet un evenemnt de transition
     */
    function incrementStatus() external onlyOwner {
        previous = getPrevious();
        require(
            uint8(previous) <= uint8(WorkflowStatus.VotesTallied),
            "Index hors du tableau"
        );
        defaultstate = WorkflowStatus(uint8(previous) + 1);
        emit WorkflowStatusChange(previous, defaultstate);
    }

    /* @title : StartProposition
    *  @param : string memory  _PropositionDescription 
    *   @Dev: Permet de soumettre un proposition de vote
    *   @Dev: controle si les voteurs sont enregistrés
        @Dev: Push la proposition, récupérer identifiant de tableau et génére un evenement de soumission de proposition
    */
    //L'administrateur du vote commence la session d'enregistrement de la proposition.
    // Appel de la fonction ManageVotingFlow avec parametre 1
    // Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.

    function StartProposition(string memory _PropositionDescription)
        external
        atStage(WorkflowStatus.ProposalsRegistrationStarted)
        CheckRegistration
    {
        //si les enregistrements des propositions sont ouvertes alors les personnes de la whiteList
        //peuvent ajouter leurs propositions

        votePropositions.push(
            Proposal({description: _PropositionDescription, voteCount: 0})
        );

        uint8 proposalId = uint8(votePropositions.length - 1);
        emit ProposalRegistered(proposalId);
    }

    /* @title : getProposals
    *  @param : Proposal[] memory, uint[] memory
    *   @Dev: Recupere les propositions dans un tableau Proposal
    *   @Dev: Recupere les identifiant dans un autre tableau mais dans l'ordre
              afin de connaitre id des propisitions à utliser pour le vote
    */

    function getProposals() external view returns (Proposal[] memory) {
        return votePropositions;
    }

    /* @title : vote
     *  @param : _chooseProposal : implémente le choix de vote dans la variable
     * @modifier : atStage : permet de limiter l'utilisation a une étapes spécifique de vote ouvert
     *   @require: un votant ne peut pas voter deux fois
     *   @Dev: on incremente le nombre de vote pour cette propostion
     *   @Dev: on emet un event pour signaler que le vote à eu lieu
     */

    function vote(uint8 _chooseProposal)
        external
        atStage(WorkflowStatus.VotingSessionStarted)
        CheckRegistration
    {
        Voter storage voteur = whiteListedPeople[msg.sender];
        //confirmation que l'addresse n'a pas déjà voté
        require(!voteur.hasVoted, "Vous ne pouvez pas voter deux fois.");
        //mettre à jour le statue du vote pour l'addresse
        voteur.hasVoted = true;
        //mettre à jour l'index de la propositon depuis les parametres
        voteur.votedProposalId = _chooseProposal;

        //incrementer dans proposals le vote à l'identifiant passser en parametre
        votePropositions[_chooseProposal].voteCount++;

        //declenchement de l'évement à voter
        emit Voted(msg.sender, _chooseProposal);
    }

    /* @title : winningProposition
     *  goal: determiner quelle est la propistions avec le plus de vote
     *  return : _winningProposalId qui est l'identifiant de la proposition gagnante
     */

    //determiner quelle proposition possedent le plus de vote

    function winningProposition()
        internal
        view
        returns (uint256 _winningProposalId)
    {
        //je recupere la valeur de voteCount par votingproposale dans un tableau
        uint8 _winningCount = 0;
        for (uint8 i = 0; i < votePropositions.length; i++) {
            if (votePropositions[i].voteCount > _winningCount) {
                _winningCount = votePropositions[i].voteCount;
                _winningProposalId = i;
            }
        }
        return _winningProposalId;
    }

    /* @title : winningProposal
     *  goal: retourne la proposition gagnante
     *  Dev : winningProposition() est appelé pour récupérer l'id de la proposition gagnante
     */

    function getWinner()
        external
        view
        atStage(WorkflowStatus.VotesTallied)
        returns (string memory winnerProp)
    {
        winnerProp = votePropositions[winningProposition()].description;
    }

    //retourne les infomations sur les votants à la fin du processus du vote
    function getAllVotersInfo(address _address)
        external
        view
        atStage(WorkflowStatus.VotesTallied)
        returns (
            address,
            bool,
            bool,
            uint256
        )
    {
        bool isRegistered = whiteListedPeople[_address].isRegistered;
        bool hasVoted = whiteListedPeople[_address].hasVoted;
        uint256 votedProposalId = whiteListedPeople[_address].votedProposalId;
        return (_address, isRegistered, hasVoted, votedProposalId);
    }

    //Fonction supplementaires///

    /* @title : DecideToChangeVote
     *  goal: Permet de modifier son vote pendant la phase devote uniquement si on a deja voté une fois.
     *  Dev : Incrémente le vote pour la nouvelle propostion et décremente pour l'ancienne proposition
     */

    function DecideToChangeVote(uint8 _changeProposal)
        external
        atStage(WorkflowStatus.VotingSessionStarted)
        CheckRegistration
    {
        Voter storage voteur_change_vote = whiteListedPeople[msg.sender];
        //confirmation que l'addresse n'a pas déjà voté
        require(
            voteur_change_vote.hasVoted,
            "Vous n'avez pas encore vote, vous ne pouvez modifier un vote non prealablement enregistre!"
        );

        //récupère l'ancien vote dans old_vote
        uint8 old_vote = voteur_change_vote.votedProposalId;
        //decrementer le vote sur l'ancienne proposition
        votePropositions[old_vote].voteCount--;

        //mettre à jour l'index de la propositon depuis les parametres
        voteur_change_vote.votedProposalId = _changeProposal;
        //incrementer dans proposals le vote à l'identifiant passser en parametre
        votePropositions[_changeProposal].voteCount++;
    }
}
