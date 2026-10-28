import '../entities/offer.dart';

abstract class OfferRepository {
  Future<List<Offer>> getActiveOffers();
}
